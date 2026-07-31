/* ═══════════════════════════════════════════════════════════════════════════
   report-sim.js — shared simulation engine for setConsensusLayerData
   ---------------------------------------------------------------------------
   A wei-exact (BigInt) port of LibOracleReporting.setConsensusLayerData and
   every handler it drives, mirroring the source statement by statement.

   Loaded by both views so the two pages can never disagree about behaviour:
     · oracle-report-simulator.html  — step-by-step execution trace
     · oracle-report-flows.html      — value flow between buckets

   Reference: contracts/src/libraries/LibOracleReporting.sol
              contracts/src/River.1.sol:454              (_assetBalance)
              contracts/src/components/SharesManager.1.sol:200-221
   Plain <script> (not a module) so file:// works with no server.
   ═══════════════════════════════════════════════════════════════════════════ */
(function (global) {
"use strict";

/* ───────────────────────────── wei helpers ───────────────────────────── */
const WAD = 10n**18n, GWEI = 10n**9n, BP = 10000n, ONE_YEAR = 31536000n, ONE_DAY = 86400n;
const min = (a,b) => a<b?a:b, max = (a,b) => a>b?a:b, abs = a => a<0n?-a:a;

function toWei(s){
  s = String(s ?? "").trim();
  if(!s) return 0n;
  let neg = s[0]==="-"; if(neg) s = s.slice(1);
  let [i,f=""] = s.split(".");
  i = i.replace(/[^0-9]/g,"") || "0";
  f = (f.replace(/[^0-9]/g,"") + "0".repeat(18)).slice(0,18);
  const v = BigInt(i)*WAD + BigInt(f);
  return neg ? -v : v;
}
const grp = s => s.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
function fmt(w, dp){
  dp = dp===undefined ? 6 : dp;
  if(w===undefined||w===null) return "–";
  let neg = w<0n; if(neg) w = -w;
  const fs = (w%WAD).toString().padStart(18,"0").slice(0,dp).replace(/0+$/,"");
  return (neg?"−":"") + grp((w/WAD).toString()) + (fs?"."+fs:"");
}
const esc = s => String(s).replace(/[&<>]/g, c=>({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));

/* ───────────────────────────── input schema ───────────────────────────── */
// kind: w = ETH amount (stored as wei), n = plain integer, b = basis points, c = checkbox
const SCHEMA = [
  ["lastStoredReport", [
    ["last.epoch",                        "epoch",                          "n", ""],
    ["last.validatorsBalance",            "validatorsBalance",              "w", "Ξ"],
    ["last.validatorsSkimmedBalance",     "validatorsSkimmedBalance",       "w", "Ξ"],
    ["last.validatorsExitedBalance",      "validatorsExitedBalance",        "w", "Ξ"],
    ["last.totalDepositedActivatedETH",   "totalDepositedActivatedETH",     "w", "Ξ"],
    ["last.totalExternalConsolidationETH","totalExternalConsolidationETH",  "w", "Ξ"],
    ["last.validatorsCount",              "validatorsCount",                "n", ""],
  ], null],
  ["Ambient storage", [
    ["balanceToDeposit",    "balanceToDeposit",     "w", "Ξ"],
    ["balanceToRedeem",     "balanceToRedeem",      "w", "Ξ"],
    ["committedBalance",    "committedBalance",     "w", "Ξ"],
    ["inFlightDeposit",     "inFlightDeposit",      "w", "Ξ"],
    ["consolidationBuffer", "consolidationBuffer",  "w", "Ξ"],
    ["shares",              "totalSupply (shares)", "w", "Ξ"],
  ], "These six + stored <code>validatorsBalance</code> are the whole of "
    +"<code>_assetBalance()</code>. Exiting / skimmed / exited totals are <em>not</em> in it."],
  ["Incoming _report", [
    ["rep.epoch",                        "epoch",                         "n", ""],
    ["rep.validatorsBalance",            "validatorsBalance",             "w", "Ξ"],
    ["rep.validatorsSkimmedBalance",     "validatorsSkimmedBalance",      "w", "Ξ"],
    ["rep.validatorsExitedBalance",      "validatorsExitedBalance",       "w", "Ξ"],
    ["rep.validatorsExitingBalance",     "validatorsExitingBalance",      "w", "Ξ"],
    ["rep.totalDepositedActivatedETH",   "totalDepositedActivatedETH",    "w", "Ξ"],
    ["rep.totalExternalConsolidationETH","totalExternalConsolidationETH", "w", "Ξ"],
    ["rep.validatorsCount",              "validatorsCount",               "n", ""],
    ["rebalance", "rebalanceDepositToRedeemMode", "c", ""],
    ["slashing",  "slashingContainmentMode",      "c", ""],
  ], null],
  ["Collaborators · pull ceilings", [
    ["withdrawBal",       "Withdraw contract",         "w", "Ξ"],
    ["elFeeBal",          "ELFeeRecipient",            "w", "Ξ"],
    ["exceedingEth",      "RedeemManager exceeding",   "w", "Ξ"],
    ["coverageBal",       "CoverageFund",              "w", "Ξ"],
    ["consolCovBal",      "ConsolidationCoverageFund", "w", "Ξ"],
    ["redeemDemand",      "redeemDemand (shares)",     "w", "Ξ"],
    ["requestedExits",    "totalETHExitsRequested",    "w", "Ξ"],
    ["exitedExits",       "totalExitedETH (registry)", "w", "Ξ"],
    ["coverageZero",      "coverageFund == address(0)",             "c", ""],
    ["consolCovZero",     "consolidationCoverageFund == address(0)","c", ""],
  ], null],
  ["Config", [
    ["currentEpoch",   "currentEpoch (chain now)",    "n", ""],
    ["epochsToFinality","epochsToAssumedFinality",    "n", ""],
    ["epochsPerFrame", "epochsPerFrame",              "n", ""],
    ["secondsPerSlot", "secondsPerSlot",              "n", "s"],
    ["slotsPerEpoch",  "slotsPerEpoch",               "n", ""],
    ["aprUpper",       "annualAprUpperBound",         "b", "bp"],
    ["lowerBound",     "relativeLowerBound",          "b", "bp"],
    ["globalFee",      "globalFee",                   "b", "bp"],
    ["minDailyNet",    "minDailyNetCommittableAmount","w", "Ξ"],
    ["maxDailyRel",    "maxDailyRelativeCommittable", "b", "bp"],
  ], null],
  ["Model override", [
    ["overridePost",   "override postReportUnderlyingBalance", "c", ""],
    ["postOverride",   "postReportUnderlyingBalance",          "w", "Ξ"],
  ], "With the override on, <code>_assetBalance()</code> is still simulated faithfully "
    +"everywhere else — only the line 213 read is replaced, so the identity no longer applies."],
];

const KIND = {};
SCHEMA.forEach(g => g[1].forEach(r => { KIND[r[0]] = r[2]; }));

/* ───────────────────────────── presets ───────────────────────────── */
const BASE = {
  "last.epoch":"1125","last.validatorsBalance":"3200","last.validatorsSkimmedBalance":"10",
  "last.validatorsExitedBalance":"64","last.totalDepositedActivatedETH":"3200",
  "last.totalExternalConsolidationETH":"0","last.validatorsCount":"100",
  balanceToDeposit:"50", balanceToRedeem:"0", committedBalance:"32", inFlightDeposit:"64",
  consolidationBuffer:"100", shares:"3300",
  "rep.epoch":"1350","rep.validatorsBalance":"3302.4","rep.validatorsSkimmedBalance":"12",
  "rep.validatorsExitedBalance":"64","rep.validatorsExitingBalance":"32",
  "rep.totalDepositedActivatedETH":"3264","rep.totalExternalConsolidationETH":"40",
  "rep.validatorsCount":"102", rebalance:false, slashing:false,
  withdrawBal:"10", elFeeBal:"2", exceedingEth:"5", coverageBal:"10", consolCovBal:"25",
  redeemDemand:"0", requestedExits:"0", exitedExits:"0",
  coverageZero:false, consolCovZero:false,
  currentEpoch:"1400", epochsToFinality:"4", epochsPerFrame:"225",
  secondsPerSlot:"12", slotsPerEpoch:"32",
  aprUpper:"1000", lowerBound:"500", globalFee:"1250",
  minDailyNet:"3200", maxDailyRel:"500",
  overridePost:false, postOverride:"0",
};
const PRESETS = {
  "Happy path": {},
  "Buffer overshoot": {
    consolidationBuffer:"39.9",
    "rep.validatorsBalance":"3240.4", "rep.validatorsSkimmedBalance":"10",
    "rep.totalDepositedActivatedETH":"3200", "rep.totalExternalConsolidationETH":"40",
  },
  "Budget spillover": { aprUpper:"20000", elFeeBal:"0.2", exceedingEth:"0.3", coverageBal:"40" },
  "Rebalance to redeem": { rebalance:true, redeemDemand:"300" },
  "Exit demand only":   { rebalance:false, redeemDemand:"300" },
  "Slashing containment": { slashing:true, redeemDemand:"300" },
  "Reported loss":      { "rep.validatorsBalance":"3150", aprUpper:"20000",
                          elFeeBal:"1", coverageBal:"60" },
  "Lower-bound breach": { "rep.validatorsBalance":"3000" },
  "CL pull shortfall":  { withdrawBal:"1" },
  "Consol. decrease":   { "rep.totalExternalConsolidationETH":"0",
                          "last.totalExternalConsolidationETH":"10" },
};

/* ───────────────────────────── shared input UI ───────────────────────────── */
function renderInputs(host, title){
  host.innerHTML = `<h2 class="pt">${title || "Inputs · amounts in ETH"}</h2>`
    + SCHEMA.map(g => {
      const [name, rows, hint] = g;
      return `<fieldset><legend>${name}</legend>` + rows.map(r => {
        const [k,label,kind,u] = r;
        return kind==="c"
          ? `<div class="row ck"><input type="checkbox" id="f_${k}">`
            + `<label for="f_${k}">${label}</label></div>`
          : `<div class="row"><label for="f_${k}">${label}</label>`
            + `<input type="text" id="f_${k}" spellcheck="false"><span class="u">${u}</span></div>`;
      }).join("") + (hint?`<p class="hint">${hint}</p>`:"") + `</fieldset>`;
    }).join("");
}

function setFields(name){
  const v = Object.assign({}, BASE, PRESETS[name] || {});
  for(const k in KIND){
    const el = document.getElementById("f_"+k);
    if(!el) continue;
    if(KIND[k]==="c") el.checked = !!v[k]; else el.value = v[k] === undefined ? "0" : v[k];
  }
}

function renderPresets(host, onPick){
  host.innerHTML = Object.keys(PRESETS).map(n=>`<button>${n}</button>`).join("");
  Array.prototype.forEach.call(host.querySelectorAll("button"), b => {
    b.onclick = () => {
      setFields(b.textContent);
      Array.prototype.forEach.call(host.querySelectorAll("button"),
        x => x.classList.toggle("on", x === b));
      onPick(b.textContent);
    };
  });
}

function markPreset(host, name){
  Array.prototype.forEach.call(host.querySelectorAll("button"),
    b => b.classList.toggle("on", b.textContent === name));
}

function readInputs(){
  const o = {};
  for(const k in KIND){
    const el = document.getElementById("f_"+k);
    if(!el) continue;
    if(KIND[k]==="c") o[k] = el.checked;
    else if(KIND[k]==="w") o[k] = toWei(el.value);
    else o[k] = BigInt((el.value||"0").replace(/[^0-9-]/g,"")||"0");
  }
  return o;
}

/* ═════════════════════════════ the simulation ═════════════════════════════ */
function simulate(f){
  const steps = [], guards = [], ledger = [], flows = [], shareFlows = [];
  const S = {                                        // mutable storage mirror
    vb: f["last.validatorsBalance"],
    btd: f.balanceToDeposit, btr: f.balanceToRedeem, cb: f.committedBalance,
    ifd: f.inFlightDeposit, buf: f.consolidationBuffer, sh: f.shares,
  };
  // River.1.sol:454 — the entire asset balance, six terms, nothing else
  const assetBalance = () => S.vb + S.btd + S.cb + S.btr + S.ifd + S.buf;
  const underlyingFromShares = s => S.sh===0n ? 0n : (s*assetBalance())/S.sh;
  const sharesFromUnderlying = b => { const a=assetBalance(); return a===0n?0n:(b*S.sh)/a; };

  const out = { steps, guards, ledger, flows, shareFlows, reverted:null,
                identity:null, wf:null, conservation:null,
                trace:{ rewards:0n, pulledELFees:0n, pulledExceeding:0n,
                        pulledCoverage:0n, pulledConsolCoverage:0n } };

  const snap = label => ledger.push({label, vb:S.vb, btd:S.btd, btr:S.btr, cb:S.cb,
                                     ifd:S.ifd, buf:S.buf, ab:assetBalance(), sh:S.sh});
  const push = s => { steps.push(s); return s; };
  const guard = (label, ok, margin) => guards.push({label, ok, margin});
  const flow = (from, to, amt, step, kind, note) => {
    if(amt && amt !== 0n) flows.push({from, to, amt, step, kind, note});
  };
  const REVERT = (lines, name, msg) => {
    push({lines, kind:"revert", name:"revert "+name, tag:["r","revert"], err:msg});
    out.reverted = {name, msg};
    return out;
  };

  /* ── 79–88 · auth + epoch validity ── */
  {
    const e = f["rep.epoch"], le = f["last.epoch"];
    const cA = f.currentEpoch >= e + f.epochsToFinality;
    const cB = e > le;
    const cC = f.epochsPerFrame !== 0n && e % f.epochsPerFrame === 0n;
    const ok = cA && cB && cC;
    guard("Valid epoch", ok, ok ? "" : (!cA?"not final":!cB?"≤ last":"off-frame"));
    push({lines:"79–88", kind: ok?"pass":"revert", name:"Auth &amp; epoch validity",
      tag: ok?["g","pass"]:["r","revert"],
      cond:[`msg.sender == OracleAddress.get()            ✓ (assumed)`,
            `currentEpoch ${f.currentEpoch} ≥ epoch+finality ${e+f.epochsToFinality}  ${cA?"✓":"✗"}`,
            `epoch ${e} &gt; lastReport.epoch ${le}   ${cB?"✓":"✗"}`,
            `epoch ${e} % epochsPerFrame ${f.epochsPerFrame} == 0   ${cC?"✓":"✗"}`].join("\n")});
    if(!ok) return REVERT("87","InvalidEpoch",`InvalidEpoch(${e})`);
  }

  /* ── 95–162 · monotonicity gauntlet ── */
  let exitedInc=0n, skimmedInc=0n, activatedInc=0n, extConsolInc=0n, lastBuf=0n,
      increaseInConsol=0n, overshoot=0n, elapsed=0n;
  {
    const L = f["last.validatorsExitedBalance"], R = f["rep.validatorsExitedBalance"];
    guard("exited not decreasing", R>=L, fmt(R-L,4));
    if(R<L) return REVERT("99","InvalidDecreasingValidatorsExitedBalance",
      `InvalidDecreasingValidatorsExitedBalance(${fmt(L)}, ${fmt(R)})`);
    exitedInc = R-L;

    const sL = f["last.validatorsSkimmedBalance"], sR = f["rep.validatorsSkimmedBalance"];
    guard("skimmed not decreasing", sR>=sL, fmt(sR-sL,4));
    if(sR<sL) return REVERT("110","InvalidDecreasingValidatorsSkimmedBalance",
      `InvalidDecreasingValidatorsSkimmedBalance(${fmt(sL)}, ${fmt(sR)})`);

    const aL = f["last.totalDepositedActivatedETH"], aR = f["rep.totalDepositedActivatedETH"];
    guard("activated not decreasing", aR>=aL, fmt(aR-aL,4));
    if(aL>aR) return REVERT("117","InvalidTotalDepositedActivatedETHDecrease",
      `InvalidTotalDepositedActivatedETHDecrease(${fmt(aL)}, ${fmt(aR)})`);
    activatedInc = aR-aL;

    guard("activatedInc ≤ inFlight", activatedInc<=S.ifd, fmt(S.ifd-activatedInc,4));
    if(activatedInc>S.ifd) return REVERT("128","InvalidTotalDepositedActivatedETHIncrease",
      `InvalidTotalDepositedActivatedETHIncrease(${fmt(S.ifd)}, ${fmt(aR)})`);

    const cL = f["last.validatorsCount"], cR = f["rep.validatorsCount"];
    guard("count not decreasing", cR>=cL, String(cR-cL));
    if(cR<cL) return REVERT("135","InvalidValidatorCountReport",
      `InvalidValidatorCountReport(${cR}, ${cL})`);

    const xL = f["last.totalExternalConsolidationETH"],
          xR = f["rep.totalExternalConsolidationETH"];
    guard("extConsol not decreasing", xR>=xL, fmt(xR-xL,4));
    if(xR<xL) return REVERT("141","InvalidTotalConsolidationsAmountReportedDecrease",
      `InvalidTotalConsolidationsAmountReportedDecrease(${fmt(xL)}, ${fmt(xR)})`);

    if(xR>xL){
      increaseInConsol = xR-xL;
      lastBuf = S.buf;                                   // captured here, reused at line 179
      extConsolInc = increaseInConsol > lastBuf ? lastBuf : increaseInConsol;
      overshoot    = increaseInConsol > lastBuf ? increaseInConsol - lastBuf : 0n;
    }
    skimmedInc = sR-sL;
    elapsed = (f["rep.epoch"] - f["last.epoch"]) * (f.secondsPerSlot * f.slotsPerEpoch);

    push({lines:"95–162", kind:"pass", name:"Monotonicity gauntlet · 6 checks",
      tag:["g","6/6 pass"],
      cond:[`exited     ${fmt(R,3)} ≥ ${fmt(L,3)}  ✓ → <b>exitedAmountIncrease   = ${fmt(exitedInc)}</b>`,
            `skimmed    ${fmt(sR,3)} ≥ ${fmt(sL,3)}  ✓ → <b>skimmedAmountIncrease  = ${fmt(skimmedInc)}</b>`,
            `activated  ${fmt(aR,3)} ≥ ${fmt(aL,3)}  ✓ → <b>activatedETHIncrease   = ${fmt(activatedInc)}</b>`,
            `                              ${fmt(activatedInc)} ≤ inFlight ${fmt(S.ifd)} ✓`,
            `count      ${cR} ≥ ${cL}  ✓`,
            `extConsol  ${fmt(xR,3)} ≥ ${fmt(xL,3)}  ✓`].join("\n")});
  }

  /* ── 146–159 · consolidation clamp ── */
  if(increaseInConsol>0n){
    push({lines:"146–159", kind:"taken", name:"Consolidation clamp",
      tag: overshoot>0n ? ["b","overshoot "+fmt(overshoot,4)] : ["g","no overshoot"],
      cond:[`increaseInConsolidation = ${fmt(f["rep.totalExternalConsolidationETH"])} − `
            +`${fmt(f["last.totalExternalConsolidationETH"])} = ${fmt(increaseInConsol)}`,
            `${fmt(increaseInConsol)} &gt; lastConsolidationBuffer ${fmt(lastBuf)} ? `
            +`<b>${overshoot>0n?"YES":"NO"}</b>`,
            `→ <b>totalExternalConsolidationETHIncrease = ${fmt(extConsolInc)}</b>`].join("\n"),
      notes: overshoot>0n
        ? [["f",`Clamped to the buffer. The ${fmt(overshoot)} Ξ surplus is <em>not</em> `
             +`subtracted from the buffer, so it stays inside the <code>validatorsBalance</code> `
             +`rise and is attributed to yield — consuming upper-bound headroom.`]]
        : [["",`Had it overshot, the excess would stay inside <code>validatorsBalance</code> and `
             +`be treated as rewards, with the buffer drawdown clamped.`]]});
  } else {
    push({lines:"146–159", kind:"skipped", name:"Consolidation clamp", tag:["s","skipped"],
      cond:`totalExternalConsolidationETH unchanged → no buffer drawdown`});
  }

  /* ── 164–168 · elapsed + pre ── */
  const pre = assetBalance();
  snap("pre");
  push({lines:"164–168", kind:"info",
    name:"timeElapsed &amp; <code>preReportUnderlyingBalance</code>", tag:["b","read"],
    cond:[`timeElapsedSinceLastReport = (${f["rep.epoch"]} − ${f["last.epoch"]}) × `
          +`${f.secondsPerSlot} × ${f.slotsPerEpoch} = ${grp(elapsed.toString())} s`
          +`  (${fmt(elapsed*WAD/ONE_DAY,3)} d)`,
          `pre = ${fmt(S.vb,3)} + ${fmt(S.btd,3)} + ${fmt(S.cb,3)} + ${fmt(S.btr,3)} + `
          +`${fmt(S.ifd,3)} + ${fmt(S.buf,3)} = <b>${fmt(pre)}</b>`].join("\n")});

  /* ── 171–174 · _pullCLFunds ── */
  if(exitedInc + skimmedInc > 0n){
    const want = exitedInc + skimmedInc, got = min(f.withdrawBal, want);
    guard("CL pull delivers exactly", got===want, fmt(f.withdrawBal-want,4));
    if(got!==want) return REVERT("344","InvalidPulledClFundsAmount",
      `InvalidPulledClFundsAmount(${fmt(want)}, ${fmt(got)})\n`
      +`Withdraw contract holds only ${fmt(f.withdrawBal)} Ξ — pullEth sends min(balance, max).`);
    const d = [];
    if(skimmedInc>0n){ d.push(["balanceToDeposit",S.btd,S.btd+skimmedInc]); S.btd+=skimmedInc;
                       flow("withdraw","btd",skimmedInc,"CL","transfer","skimmed sweep"); }
    if(exitedInc>0n){  d.push(["balanceToRedeem", S.btr,S.btr+exitedInc]);  S.btr+=exitedInc;
                       flow("withdraw","btr",exitedInc,"CL","transfer","exited sweep"); }
    push({lines:"171–174", kind:"taken",
      name:`<code>_pullCLFunds</code>(skimmed ${fmt(skimmedInc,3)}, exited ${fmt(exitedInc,3)})`,
      tag:["g","pulled "+fmt(want,4)], deltas:d,
      notes:[["",`Skimmed ETH goes to the deposit buffer, exited ETH to the redeem buffer. `
                +`Reverts unless the delivered delta is <em>exactly</em> ${fmt(want)}.`]]});
    snap("CL");
  } else {
    push({lines:"171–174", kind:"skipped", name:"<code>_pullCLFunds</code>", tag:["s","skipped"],
      cond:"exitedAmountIncrease + skimmedAmountIncrease == 0"});
  }

  /* ── 177–181 · reported buffer drawdown ── */
  if(extConsolInc>0n){
    push({lines:"177–181", kind:"taken",
      name:"<code>_setConsolidationBuffer</code> · reported drawdown", tag:["g","taken"],
      deltas:[["consolidationBuffer", S.buf, lastBuf-extConsolInc]],
      notes:[["f","Touch 1 of 2 — the buffer is written again at line 292."]]});
    S.buf = lastBuf - extConsolInc;
    flow("buf","vb",extConsolInc,"store","recog","consolidated principal now in validatorsBalance");
    snap("buf");
  } else {
    push({lines:"177–181", kind:"skipped", name:"<code>_setConsolidationBuffer</code>",
      tag:["s","skipped"], cond:"totalExternalConsolidationETHIncrease == 0"});
  }

  /* ── 184–188 · in-flight drawdown ── */
  if(activatedInc>0n){
    push({lines:"184–188", kind:"taken", name:"In-flight drawdown", tag:["g","taken"],
      deltas:[["inFlightDeposit", S.ifd, S.ifd-activatedInc]],
      notes:[["",`Emits <code>SetInFlightETH</code>. The activated principal is already inside `
                +`the reported <code>validatorsBalance</code>, so this subtraction is what stops `
                +`it being counted twice.`]]});
    S.ifd -= activatedInc;
    flow("ifd","vb",activatedInc,"store","recog","deposit activated on the CL");
    snap("flight");
  } else {
    push({lines:"184–188", kind:"skipped", name:"In-flight drawdown", tag:["s","skipped"],
      cond:"totalDepositedActivatedETHIncrease == 0"});
  }

  /* ── 190–213 · store report, maxIncrease, post ── */
  const oldVB = S.vb;
  S.vb = f["rep.validatorsBalance"];
  const maxIncrease = (pre * f.aprUpper * elapsed) / (BP * ONE_YEAR);
  const postTrue = assetBalance();
  const post = f.overridePost ? f.postOverride : postTrue;
  snap("store");

  // ΔVB = activatedInc + extConsolInc + clYield − (skimmedInc + exitedInc)
  const clYield = (S.vb - oldVB) - activatedInc - extConsolInc + skimmedInc + exitedInc;
  if(skimmedInc + exitedInc > 0n)
    flow("vb","withdraw",skimmedInc+exitedInc,"store","sweep","skimmed + exited swept to the EL");
  if(clYield > 0n) flow("yield","vb",clYield,"store","yield","consensus layer yield");
  else if(clYield < 0n) flow("vb","loss",-clYield,"store","loss","consensus layer loss");

  push({lines:"190–213", kind:"info",
    name:"Store report → <code>postReportUnderlyingBalance</code>", tag:["b","pivot"],
    cond:[`storedReport.validatorsBalance: ${fmt(oldVB,3)} → ${fmt(S.vb,3)}`,
          `post = ${fmt(S.vb,3)} + ${fmt(S.btd,3)} + ${fmt(S.cb,3)} + ${fmt(S.btr,3)} + `
          +`${fmt(S.ifd,3)} + ${fmt(S.buf,3)} = <b>${fmt(postTrue)}</b>`
          + (f.overridePost ? `\noverride active → post = <b>${fmt(post)}</b>` : ""),
          `maxIncrease = ${fmt(pre,3)} × ${f.aprUpper}bp × ${grp(elapsed.toString())}s / `
          +`(10000 × 365d) = <b>${fmt(maxIncrease)}</b>`].join("\n"),
    notes:[["",`Four things moved between the two reads. The identity panel decomposes the `
              +`${fmt(post-pre)} Ξ delta into its five signed terms.`]]});

  out.identity = {
    terms:[["+","skimmedIncrease",          skimmedInc],
           ["+","exitedIncrease",           exitedInc],
           ["−","extConsolidationIncrease", -extConsolInc],
           ["−","activatedETHIncrease",     -activatedInc],
           [(S.vb-oldVB)<0n?"−":"+","Δ validatorsBalance", S.vb-oldVB]],
    sum: skimmedInc + exitedInc - extConsolInc - activatedInc + (S.vb-oldVB),
    actual: postTrue - pre, overridden: f.overridePost,
  };

  /* ── 219–257 · bound branch ── */
  let avail = 0n;
  if(post >= pre){
    const overBy = post - pre > maxIncrease ? (post-pre) - maxIncrease : 0n;
    guard("upper bound", overBy===0n,
      overBy===0n ? fmt(maxIncrease-(post-pre),4) : "+"+fmt(overBy,4));
    guard("lower bound", true, "n/a");
    if(overBy>0n){
      push({lines:"221–228", kind:"revert", name:"revert TotalValidatorBalanceIncreaseOutOfBound",
        tag:["r","revert"],
        err:`TotalValidatorBalanceIncreaseOutOfBound(\n  prev  ${fmt(pre)},\n  post  ${fmt(post)},`
           +`\n  time  ${grp(elapsed.toString())},\n  apr   ${f.aprUpper} bp\n)\n`
           +`delta ${fmt(post-pre)} exceeds maxIncrease ${fmt(maxIncrease)} by ${fmt(overBy)}`});
      out.reverted = {name:"TotalValidatorBalanceIncreaseOutOfBound"};
      return out;
    }
    out.trace.rewards = post - pre;
    avail = maxIncrease - out.trace.rewards;
    push({lines:"219–234", kind:"taken", name:"Upper-bound branch", tag:["g","within bound"],
      cond:[`post ${fmt(post,3)} ≥ pre ${fmt(pre,3)} → increase branch`,
            `${fmt(post,3)} &gt; pre + maxIncrease ${fmt(pre+maxIncrease,3)} ? <b>NO</b>`,
            `<b>trace.rewards = ${fmt(out.trace.rewards)}</b>`,
            `<b>availableAmountToUpperBound = ${fmt(maxIncrease)} − `
            +`${fmt(out.trace.rewards)} = ${fmt(avail)}</b>`].join("\n")});
  } else {
    const maxDecrease = (pre * f.lowerBound) / BP;
    const floor = pre - min(maxDecrease, pre);
    guard("upper bound", true, "n/a");
    guard("lower bound", post>=floor, post>=floor?fmt(post-floor,4):"−"+fmt(floor-post,4));
    if(post < floor){
      push({lines:"246–251", kind:"revert", name:"revert TotalValidatorBalanceDecreaseOutOfBound",
        tag:["r","revert"],
        err:`TotalValidatorBalanceDecreaseOutOfBound(\n  prev  ${fmt(pre)},\n  post  ${fmt(post)},`
           +`\n  time  ${grp(elapsed.toString())},\n  lower ${f.lowerBound} bp\n)\n`
           +`maxDecrease ${fmt(maxDecrease)} → floor ${fmt(floor)}; post is `
           +`${fmt(floor-post)} below it`});
      out.reverted = {name:"TotalValidatorBalanceDecreaseOutOfBound"};
      return out;
    }
    avail = maxIncrease + (pre - post);
    push({lines:"235–257", kind:"taken", name:"Lower-bound branch · loss reported",
      tag:["b","within bound"],
      cond:[`post ${fmt(post,3)} &lt; pre ${fmt(pre,3)} → decrease branch`,
            `maxDecrease = ${fmt(pre,3)} × ${f.lowerBound}bp = ${fmt(maxDecrease)}`,
            `floor = ${fmt(floor)} ≤ post ✓ → no revert`,
            `<b>trace.rewards = 0</b>  (a loss never produces rewards)`,
            `<b>availableAmountToUpperBound = ${fmt(maxIncrease)} + ${fmt(pre-post)} `
            +`= ${fmt(avail)}</b>`].join("\n"),
      notes:[["f",`The loss <em>widens</em> the pull budget: the protocol may now pull up to `
                 +`${fmt(avail)} Ξ of EL fees, exceeding ETH and coverage to backfill it.`]]});
  }
  const budget0 = avail;

  /* ── 260–267 · EL fees ── */
  if(avail>0n){
    const got = min(f.elFeeBal, avail);
    out.trace.pulledELFees = got;
    const d = [];
    if(got>0n){ d.push(["balanceToDeposit",S.btd,S.btd+got]); S.btd+=got;
                flow("elfee","btd",got,"EL","transfer","execution layer fees"); }
    d.push(["trace.rewards", out.trace.rewards, out.trace.rewards+got]);
    d.push(["availableAmountToUpperBound", avail, avail-got]);
    out.trace.rewards += got; avail -= got;
    push({lines:"260–267", kind:"taken", name:`<code>_pullELFees</code>(${fmt(budget0,4)})`,
      tag:["g","pulled "+fmt(got,4)], deltas:d,
      cond:`min(recipient balance ${fmt(f.elFeeBal)}, budget ${fmt(budget0)}) = ${fmt(got)}`,
      notes:[["","The only pull that feeds <code>rewards</code>."]]});
    if(got>0n) snap("EL");
  } else {
    push({lines:"260–267", kind:"skipped", name:"<code>_pullELFees</code>", tag:["s","skipped"],
      cond:"availableAmountToUpperBound == 0"});
  }

  /* ── 270–276 · redeem manager exceeding eth ── */
  if(avail>0n){
    const b = avail, got = min(f.exceedingEth, avail);
    out.trace.pulledExceeding = got;
    const d = [];
    if(got>0n){ d.push(["balanceToDeposit",S.btd,S.btd+got]); S.btd+=got;
                flow("rmbuf","btd",got,"exceed","transfer","exceeding ETH returned"); }
    d.push(["availableAmountToUpperBound", avail, avail-got]);
    avail -= got;
    push({lines:"270–276", kind:"taken",
      name:`<code>_pullRedeemManagerExceedingEth</code>(${fmt(b,4)})`,
      tag:["g","pulled "+fmt(got,4)], deltas:d,
      cond:`min(exceeding buffer ${fmt(f.exceedingEth)}, budget ${fmt(b)}) = ${fmt(got)}`,
      notes:[["f","Drains the budget but does <em>not</em> feed rewards — it is River's own "
                 +"ETH coming home, not new yield."]]});
    if(got>0n) snap("exceed");
  } else {
    push({lines:"270–276", kind:"skipped", name:"<code>_pullRedeemManagerExceedingEth</code>",
      tag:["s","skipped"], cond:"availableAmountToUpperBound == 0"});
  }

  /* ── 279–283 · coverage funds ── */
  if(avail>0n){
    const b = avail;
    const got = f.coverageZero ? 0n : min(f.coverageBal, avail);
    out.trace.pulledCoverage = got;
    const d = [];
    if(got>0n){ d.push(["balanceToDeposit",S.btd,S.btd+got]); S.btd+=got;
                flow("cov","btd",got,"cov","transfer","coverage backfill"); }
    d.push(["availableAmountToUpperBound", avail, avail]);
    push({lines:"279–283", kind:"taken", name:`<code>_pullCoverageFunds</code>(${fmt(b,4)})`,
      tag:["g","pulled "+fmt(got,4)], deltas:d,
      cond: f.coverageZero
        ? `coverageFund == address(0) → early return 0 (line 602)`
        : `min(coverage balance ${fmt(f.coverageBal)}, budget ${fmt(b)}) = ${fmt(got)}`,
      notes:[["f","Neither rewards nor budget-draining — the one stage with no <code>-=</code> "
                 +"(line 281). Coverage backfills a loss without counting as yield."]]});
    if(got>0n) snap("cov");
  } else {
    push({lines:"279–283", kind:"skipped", name:"<code>_pullCoverageFunds</code>",
      tag:["s","skipped"], cond:"availableAmountToUpperBound == 0"});
  }

  /* ── 285–297 · consolidation coverage ── */
  {
    const bufNow = S.buf;
    if(bufNow>0n){
      const got = f.consolCovZero ? 0n : min(f.consolCovBal, bufNow);
      out.trace.pulledConsolCoverage = got;
      const d = [];
      if(got>0n){
        d.push(["balanceToDeposit",S.btd,S.btd+got]); S.btd+=got;
        d.push(["consolidationBuffer",S.buf,S.buf-got]); S.buf-=got;
        flow("buf","btd",got,"cCov","settle","receivable settled in cash by the coverage fund");
      }
      push({lines:"285–297", kind: got>0n?"taken":"skipped",
        name:"<code>_pullConsolidationCoverageFunds</code>",
        tag: got>0n?["g","pulled "+fmt(got,4)]:["s","nothing available"], deltas:d,
        cond:[`re-reads ConsolidationBuffer → ${fmt(bufNow)} &gt; 0 → attempt pull of ${fmt(bufNow)}`,
              f.consolCovZero ? `fund == address(0) → early return 0`
                              : `min(fund ${fmt(f.consolCovBal)}, ${fmt(bufNow)}) = ${fmt(got)}`
             ].join("\n"),
        notes:[["f",`Touch 2 of 2, and entirely outside the budget — gated only on `
                   +`<code>buffer &gt; 0</code>, so it can fire on every report even when the `
                   +`upper-bound budget is exhausted. Net effect on `
                   +`<code>_assetBalance()</code> is <b>zero</b>: the buffer receivable is `
                   +`simply converted into cash.`]]});
      if(got>0n) snap("cCov");
    } else {
      push({lines:"285–297", kind:"skipped", name:"<code>_pullConsolidationCoverageFunds</code>",
        tag:["s","skipped"], cond:"consolidationBuffer == 0"});
    }
  }

  /* ── 300–302 · _onEarnings ── */
  if(out.trace.rewards>0n){
    guard("shares > 0 for onEarnings", S.sh>0n, S.sh>0n?"":"zero supply");
    if(S.sh===0n) return REVERT("408","ZeroMintedShares","ZeroMintedShares()");
    const oldSupply = S.sh, newTotal = assetBalance();
    const num = out.trace.rewards * oldSupply * f.globalFee;
    const rf  = out.trace.rewards * f.globalFee;
    if(newTotal*BP < rf) return REVERT("413","panic: arithmetic underflow",
      `denominator underflow: newTotalBalance × 10000 (${fmt(newTotal*BP)}) `
      +`&lt; rewards × globalFee (${fmt(rf)})`);
    const den = newTotal*BP - rf;
    const mint = den===0n ? 0n : num/den;
    const d = mint>0n ? [["shares (collector mint)", S.sh, S.sh+mint]] : [];
    if(mint>0n){ S.sh += mint; shareFlows.push({to:"collector", amt:mint, kind:"mint",
                                               step:"fee", note:"protocol fee"}); }
    push({lines:"300–302", kind:"taken",
      name:`<code>_onEarnings</code>(${fmt(out.trace.rewards,6)})`,
      tag:["g", mint>0n?"minted "+fmt(mint,6):"nothing minted"], deltas:d,
      cond:[`oldTotalSupply = ${fmt(oldSupply,3)}   globalFee = ${f.globalFee} bp`,
            `newTotalBalance = _assetBalance() = <b>${fmt(newTotal)}</b>`,
            `sharesToMint = ${fmt(out.trace.rewards)}×${fmt(oldSupply,3)}×${f.globalFee}`
            +` / (${fmt(newTotal,3)}×10000 − ${fmt(out.trace.rewards)}×${f.globalFee})`,
            `             = <b>${fmt(mint)}</b>`].join("\n"),
      notes:[["f",`A <em>third</em> asset-balance snapshot — ${fmt(newTotal)}, not post `
                 +`${fmt(post)}. Everything pulled since line 213 has landed in `
                 +`<code>balanceToDeposit</code>, so the fee denominator is larger and the `
                 +`collector is diluted slightly relative to a naive reading.`]]});
    if(mint>0n) snap("fee");
  } else {
    guard("shares > 0 for onEarnings", true, "no rewards");
    push({lines:"300–302", kind:"skipped", name:"<code>_onEarnings</code>", tag:["s","skipped"],
      cond:"trace.rewards == 0"});
  }

  /* ── 304–316 · reportCLETH + exit demand ── */
  const base = f["rep.validatorsBalance"] + S.ifd;
  const exiting = f["rep.validatorsExitingBalance"];
  const totalAvailCLETH = base > exiting ? base - exiting : 0n;
  push({lines:"304–308", kind:"info", name:"<code>_reportCLETH</code> &amp; CL headroom",
    tag:["b","external"],
    cond:[`reportCLETH(activeCLETHPerOperator) → OperatorsRegistry`,
          `base = repVB ${fmt(f["rep.validatorsBalance"],3)} + inFlight ${fmt(S.ifd,3)} = `
          +`${fmt(base,3)}`,
          `totalAvailableCLETH = base − exiting ${fmt(exiting,3)} = <b>${fmt(totalAvailCLETH)}</b>`
         ].join("\n")});

  out.exitRequest = 0n;
  if(f.slashing){
    push({lines:"448–451", kind:"skipped", name:"Exit demand · slashing containment",
      tag:["r","short-circuit"],
      cond:`slashingContainmentMode == true → emit SkippedExitRequestsDueToSlashingContainment`,
      notes:[["f","<code>reportExitedETH</code> still ran. Only the demand logic below is "
                 +"skipped, so no rebalancing and no new exit requests this cycle."]]});
  } else if(S.sh===0n){
    push({lines:"453–496", kind:"skipped", name:"Exit demand", tag:["s","totalSupply == 0"]});
  } else {
    const btrA = S.btr, btdA = S.btd;
    const demandEth = underlyingFromShares(f.redeemDemand);
    const lines = [
      `redeemDemand ${fmt(f.redeemDemand,3)} shares → underlyingBalanceFromShares = `
      +`<b>${fmt(demandEth)}</b>`,
      `balanceToRedeem ${fmt(btrA,3)} + exiting ${fmt(exiting,3)} `
      +`${btrA+exiting < demandEth ? "&lt;" : "≥"} demand ${fmt(demandEth,3)}`];
    if(btrA + exiting < demandEth){
      const d = [];
      let btr = btrA;
      if(f.rebalance && btdA>0n){
        const amt = min(btdA, demandEth - exiting - btrA);
        if(amt>0n){
          d.push(["balanceToRedeem", S.btr, S.btr+amt]);
          d.push(["balanceToDeposit", S.btd, S.btd-amt]);
          S.btr += amt; S.btd -= amt; btr = S.btr;
          flow("btd","btr",amt,"rebal","internal","deposit→redeem rebalancing");
          lines.push(`rebalance ON → move min(btd ${fmt(btdA,3)}, `
            +`${fmt(demandEth-exiting-btrA,3)}) = <b>${fmt(amt)}</b> deposit → redeem`);
        }
      } else if(!f.rebalance){
        lines.push(`rebalance OFF → deposit buffer untouched`);
      }
      const preExiting = f.requestedExits > f.exitedExits ? f.requestedExits-f.exitedExits : 0n;
      lines.push(`preExitingBalance = requested ${fmt(f.requestedExits,3)} − exited `
        +`${fmt(f.exitedExits,3)} = ${fmt(preExiting)}`);
      if(btr + exiting + preExiting < demandEth){
        const need = demandEth - (btr + exiting + preExiting);
        const ask = max(need, WAD);
        out.exitRequest = ask;
        lines.push(`still short by ${fmt(need)} → demandETHExits(<b>${fmt(ask)}</b>, `
          +`${fmt(totalAvailCLETH,3)})` + (need<WAD?"   ← floored to 1 ether":""));
        push({lines:"462–494", kind:"taken", name:"Exit demand · requesting exits",
          tag:["g","ask "+fmt(ask,4)], deltas:d, cond:lines.join("\n"),
          notes:[["",`<code>preExitingBalance</code> is what stops exits being re-requested `
                    +`across cycles — ETH already committed to exit but not yet received.`]]});
      } else {
        push({lines:"462–494", kind:"taken", name:"Exit demand · covered without exits",
          tag:["g","no exits"], deltas:d,
          cond:lines.concat([`covered: ${fmt(btr,3)} + ${fmt(exiting,3)} + `
            +`${fmt(preExiting,3)} ≥ ${fmt(demandEth,3)} → no exit request`]).join("\n")});
      }
      if(d.length) snap("rebal");
    } else {
      push({lines:"462–494", kind:"skipped", name:"Exit demand", tag:["s","demand covered"],
        cond:lines.join("\n")});
    }
  }

  /* ── 319 · report withdraw to redeem manager ── */
  let withdrawOut = 0n;
  {
    const ab = assetBalance();
    if(ab>0n && S.sh>0n){
      const demand = f.redeemDemand;
      let supplied = demand, suppliedEth = underlyingFromShares(supplied);
      const availBTR = S.btr;
      const clamped = suppliedEth > availBTR;
      const lines = [`redeemManagerDemand = ${fmt(demand,3)} shares → ${fmt(suppliedEth)} Ξ`,
                     `availableBalanceToRedeem = ${fmt(availBTR)}`];
      if(clamped){
        suppliedEth = availBTR;
        supplied = sharesFromUnderlying(suppliedEth);
        lines.push(`demand &gt; available → clamp to ${fmt(suppliedEth)} Ξ = `
          +`<b>${fmt(supplied)}</b> shares`);
      }
      const d = [];
      if(suppliedEth>0n){
        d.push(["balanceToRedeem", S.btr, S.btr-suppliedEth]); S.btr -= suppliedEth;
        d.push(["shares (RM burn)", S.sh, S.sh-supplied]); S.sh -= supplied;
        withdrawOut = suppliedEth;
        flow("btr","rm",suppliedEth,"withdraw","outflow","reportWithdraw payout");
        shareFlows.push({from:"rm", amt:supplied, kind:"burn", step:"withdraw",
                         note:"redeem manager shares burnt"});
      }
      push({lines:"319", kind: suppliedEth>0n?"taken":"skipped",
        name:"<code>_reportWithdrawToRedeemManager</code>",
        tag: suppliedEth>0n?["g","sent "+fmt(suppliedEth,4)]:["s","nothing to supply"],
        deltas:d, cond:lines.join("\n"),
        notes: suppliedEth>0n
          ? [["",`Burns the redeem manager's shares and forwards the ETH. `
                +`<code>sharesFromUnderlyingBalance</code> is evaluated <em>before</em> the `
                +`buffer is debited, so it uses asset balance ${fmt(ab)}.`]]
          : []});
      if(suppliedEth>0n) snap("withdraw");
    } else {
      push({lines:"319", kind:"skipped", name:"<code>_reportWithdrawToRedeemManager</code>",
        tag:["s","skipped"],
        cond:`assetBalance ${fmt(ab)} / totalSupply ${fmt(S.sh)} — one is 0`});
    }
  }

  /* ── 322 · skim excess ── */
  if(S.btr>0n){
    push({lines:"322", kind:"taken", name:"<code>_skimExcessBalanceToRedeem</code>",
      tag:["g","skimmed "+fmt(S.btr,4)],
      deltas:[["balanceToDeposit",S.btd,S.btd+S.btr],["balanceToRedeem",S.btr,0n]],
      notes:[["",`All redeem demand is satisfied, so leftover redeem ETH is redirected `
                +`to deposits.`]]});
    flow("btr","btd",S.btr,"skim","internal","excess redeem balance skimmed");
    S.btd += S.btr; S.btr = 0n;
    snap("skim");
  } else {
    push({lines:"322", kind:"skipped", name:"<code>_skimExcessBalanceToRedeem</code>",
      tag:["s","no-op"], cond:"balanceToRedeem == 0"});
  }

  /* ── 325 · commit balance to deposit ── */
  if(f.slashing){
    push({lines:"556–559", kind:"skipped", name:"<code>_commitBalanceToDeposit</code>",
      tag:["r","short-circuit"],
      cond:"slashingContainmentMode == true → emit SkippedCommitToDepositDueToSlashingContainment",
      notes:[["f",`${fmt(S.btd)} Ξ stays in the deposit buffer — still available for redeem `
                 +`rebalancing next cycle, but nothing is committed to new validators.`]]});
  } else {
    const ab = assetBalance(), btd = S.btd;
    const rel = (f.maxDailyRel * (ab - btd)) / BP;
    const maxDaily = max(f.minDailyNet, rel);
    let amt = min((maxDaily * elapsed) / ONE_DAY, btd);
    const preFloor = amt;
    amt = (amt / GWEI) * GWEI;
    const d = [];
    if(amt>0n){
      d.push(["committedBalance", S.cb, S.cb+amt]);
      d.push(["balanceToDeposit", S.btd, S.btd-amt]);
      S.cb += amt; S.btd -= amt;
      flow("btd","cb",amt,"commit","internal","committed to new validators");
    }
    push({lines:"325", kind: amt>0n?"taken":"skipped",
      name:`<code>_commitBalanceToDeposit</code>(${fmt(elapsed*WAD/ONE_DAY,3)} d)`,
      tag: amt>0n?["g","committed "+fmt(amt,4)]:["s","nothing committable"], deltas:d,
      cond:[`maxDaily = max(minNet ${fmt(f.minDailyNet,3)}, ${f.maxDailyRel}bp × `
            +`(${fmt(ab,3)} − ${fmt(btd,3)})) = max(${fmt(f.minDailyNet,3)}, ${fmt(rel,3)}) = `
            +`<b>${fmt(maxDaily,3)}</b>`,
            `maxCommittable = min(${fmt(maxDaily,3)} × period/1d, btd ${fmt(btd)}) = `
            +`${fmt(preFloor)}`,
            `gwei-floored → <b>${fmt(amt)}</b>`
            + (preFloor!==amt ? `   (dropped ${(preFloor-amt).toString()} wei)` : "")].join("\n"),
      notes:[["",`The relative cap deliberately excludes <code>balanceToDeposit</code>, so it `
                +`scales with funds already at work on the CL rather than with the queue.`]]});
    if(amt>0n) snap("commit");
  }

  push({lines:"328", kind:"info", name:"emit <code>ProcessedConsensusLayerReport</code>",
    tag:["b","done"],
    cond:[`rewards                       ${fmt(out.trace.rewards)}`,
          `pulledELFees                  ${fmt(out.trace.pulledELFees)}`,
          `pulledRedeemManagerExceeding  ${fmt(out.trace.pulledExceeding)}`,
          `pulledCoverageFunds           ${fmt(out.trace.pulledCoverage)}`,
          `pulledConsolidationCoverage   ${fmt(out.trace.pulledConsolCoverage)}`].join("\n")});

  out.wf = { maxIncrease, budget0, rewardsCL: post>=pre ? post-pre : 0n,
             loss: post<pre ? pre-post : 0n, remaining: avail, t: out.trace };
  out.pre = pre; out.post = post; out.postTrue = postTrue;
  out.clYield = clYield; out.overshoot = overshoot;
  out.finalAB = assetBalance(); out.withdrawOut = withdrawOut;
  out.elapsed = elapsed; out.totalAvailCLETH = totalAvailCLETH;

  /* Whole-call conservation of _assetBalance(). Everything else cancels:
     activation, consolidation recognition, the CL sweep and its pull, the
     consolidation-coverage settlement, rebalancing, skimming and committing. */
  const sum = clYield + out.trace.pulledELFees + out.trace.pulledExceeding
            + out.trace.pulledCoverage - withdrawOut;
  out.conservation = { delta: out.finalAB - pre, clYield,
    elFees: out.trace.pulledELFees, exceeding: out.trace.pulledExceeding,
    coverage: out.trace.pulledCoverage, withdrawOut, sum,
    ok: sum === out.finalAB - pre };
  return out;
}

/* ───────────────────────────── bucket metadata ───────────────────────────── */
// Shared by the flow view. `internal` = counted inside _assetBalance().
const NODES = {
  vb:       {label:"validatorsBalance",   short:"CL balance",   internal:true,  key:"vb"},
  ifd:      {label:"inFlightDeposit",     short:"in flight",    internal:true,  key:"ifd"},
  buf:      {label:"consolidationBuffer", short:"consol. buf",  internal:true,  key:"buf"},
  btd:      {label:"balanceToDeposit",    short:"to deposit",   internal:true,  key:"btd"},
  btr:      {label:"balanceToRedeem",     short:"to redeem",    internal:true,  key:"btr"},
  cb:       {label:"committedBalance",    short:"committed",    internal:true,  key:"cb"},
  withdraw: {label:"Withdraw contract",   short:"Withdraw",     internal:false},
  elfee:    {label:"ELFeeRecipient",      short:"EL fees",      internal:false},
  rmbuf:    {label:"RM exceeding buffer", short:"RM buffer",    internal:false},
  cov:      {label:"CoverageFund",        short:"coverage",     internal:false},
  rm:       {label:"RedeemManager",       short:"RedeemManager",internal:false},
  yield:    {label:"CL yield",            short:"yield",        internal:false, source:true},
  loss:     {label:"CL loss",             short:"loss",         internal:false, sink:true},
};

global.ReportSim = {
  WAD, GWEI, BP, ONE_YEAR, ONE_DAY,
  min, max, abs, toWei, fmt, grp, esc,
  SCHEMA, KIND, BASE, PRESETS, NODES,
  renderInputs, renderPresets, setFields, markPreset, readInputs, simulate,
};
})(window);
