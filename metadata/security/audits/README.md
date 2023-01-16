# Liquid Collective Security Audits

## 2022-07 Halborn Security Audit

### Audit Dates

July 1st, 2022 -> August 2nd, 2022.

### Audit Scope

Full protocol audit including all smart contracts as per commit [6c2bef46955b2e38dfebc7e135ee86b616fcbcb9](https://github.com/liquid-collective/liquid-collective-protocol/tree/6c2bef46955b2e38dfebc7e135ee86b616fcbcb9)

It covers the following smart contracts
- River
- Oracle
- Allowlist
- Withdraw
- ELFeeRecipient
- WLSETH
- Firewall
- TUPProxy
- Initializable

### Audit Summary

|    **Severity**   | **Count** | **Fixed** | **Acknowledged** |
|:-----------------:|:---------:|:---------:|:----------------:|
|   Critical Risk   |     0     |     0     |         0        |
|     High Risk     |     1     |     1     |         0        |
|    Medium Risk    |     4     |     4     |         0        |
|      Low risk     |     5     |     3     |         2        |
| Gas Optimizations |     -     |     -     |         -        |
|   Informational   |     5     |     4     |         1        |
|     **Total**     |     15    |     12    |         3        |

See [full report](202207_Halborn_Security%20Audit%20Report.pdf) for more details.

## 2022-09 Spearbit Security Audit

### Audit Dates

August 29st, 2022 -> September 30th, 2022.

### Audit Scope

Full audit of the whole protocol including all smart contracts as per commit [778d71c5c2b0bb7d430b60df72b4d65173ebee6a](https://github.com/liquid-collective/liquid-collective-protocol/commit/778d71c5c2b0bb7d430b60df72b4d65173ebee6a)

It covers the following smart contracts
- River
- OperatorsRegistry
- Oracle
- Allowlist
- Withdraw
- ELFeeRecipient
- WLSETH
- Firewall
- TUPProxy
- Initializable

### Audit Summary

|    **Severity**   | **Count** | **Fixed** | **Acknowledged** |
|:-----------------:|:---------:|:---------:|:----------------:|
|   Critical Risk   |     3     |     3     |         0        |
|     High Risk     |     4     |     3     |         1        |
|    Medium Risk    |     15    |     12    |         3        |
|      Low risk     |     5     |     4     |         1        |
| Gas Optimizations |     19    |     18    |         1        |
|   Informational   |     39    |     32    |         17       |
|     **Total**     |     85    |     72    |         13       |

See [full report](202209_Spearbit_Security%20Audit%20Report.pdf) for more details.