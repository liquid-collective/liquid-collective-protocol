default: help

PATCH         = applyHarness.patch
MUNGED_DIR    = ./munged
CONTRACTS_DIR = ../contracts/src
file1_origin = ../contracts/src/RedeemManager.1.sol
file1_munged = ./munged/RedeemManager.1.sol
file1_copy = ./munged/RedeemManager_origin.1.sol
file2_origin = ../contracts/src/River.1.sol
file2_munged = ./munged/River.1.sol
file2_copy = ./munged/River_origin.1.sol
file3_origin = ../contracts/src/components/SharesManager.1.sol
file3_munged = ./munged/SharesManager.1.sol
file3_copy = ./munged/SharesManager_origin.1.sol
file4_origin = ../contracts/src/components/OracleManager.1.sol
file4_munged = ./munged/OracleManager.1.sol
file4_copy = ./munged/OracleManager_origin.1.sol

help:
	@echo "usage:"
	@echo "  make clean:  remove all generated files (those ignored by git)"
	@echo "  make $(MUNGED_DIR): create $(MUNGED_DIR) directory by applying the patch file to $(CONTRACTS_DIR)"
	@echo "  make record: record a new patch file capturing the differences between $(file1_munged) and $(file1_origin)"

munge:
	cp $(file1_origin) $(file1_munged)
	cp $(file1_origin) $(file1_copy)
	cp $(file2_origin) $(file2_munged)
	cp $(file2_origin) $(file2_copy)
	cp $(file3_origin) $(file3_munged)
	cp $(file3_origin) $(file3_copy)
	cp $(file4_origin) $(file4_munged)
	cp $(file4_origin) $(file4_copy)
	patch -d $(MUNGED_DIR) < $(PATCH)
	mv $(file1_munged) $(file1_origin)
	mv $(file2_munged) $(file2_origin)
	mv $(file3_munged) $(file3_origin)
	mv $(file4_munged) $(file4_origin)

record:
	diff -uN $(file1_origin) $(file1_munged) | sed 's+\$(file1_origin)/++g' | sed 's+$(file1_munged)++g' > $(PATCH)
	diff -uN $(file2_origin) $(file2_munged) | sed 's+\$(file2_origin)/++g' | sed 's+$(file2_munged)++g' >> $(PATCH)
	diff -uN $(file3_origin) $(file3_munged) | sed 's+\$(file3_origin)/++g' | sed 's+$(file3_munged)++g' >> $(PATCH)
	diff -uN $(file4_origin) $(file4_munged) | sed 's+\$(file4_origin)/++g' | sed 's+$(file4_munged)++g' >> $(PATCH)

revert:
	cp $(file1_origin) $(file1_munged)
	mv $(file1_copy) $(file1_origin)
	cp $(file2_origin) $(file2_munged)
	mv $(file2_copy) $(file2_origin)
	cp $(file3_origin) $(file3_munged)
	mv $(file3_copy) $(file3_origin)
	cp $(file4_origin) $(file4_munged)
	mv $(file4_copy) $(file4_origin)

clean:
	git clean -fdX
	touch $(PATCH)
