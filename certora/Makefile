default: help

PATCH         = applyHarness.patch
MUNGED_DIR    = ./munged
# CONTRACTS_DIR = ../contracts

# Administrable_origin = ../contracts/src/Administrable.sol
# Administrable_munged = ./munged/Administrable.sol
# Administrable_copy = ./munged/Administrable_origin.sol
River1_origin = ../contracts/src/River.1.sol
River1_munged = ./munged/River.1.sol
SharesManager1_origin = ../contracts/src/components/SharesManager.1.sol
SharesManager1_munged = ./munged/SharesManager.1.sol
# River1_copy = ./munged/River.1_origin.sol


help:
	@echo "usage:"
	@echo "  make clean:  remove all generated files (those ignored by git)"
	@echo "  make $(MUNGED_DIR): create $(MUNGED_DIR) directory by applying the patch file to $(CONTRACTS_DIR)"
	@echo "  make record: record a new patch file capturing the differences between $(CONTRACTS_DIR) and $(MUNGED_DIR)"

munged:
	rm -rf $(MUNGED_DIR)
	mkdir -p $(MUNGED_DIR)
# cp $(Administrable_origin) $(Administrable_munged)
# cp $(Administrable_origin) $(Administrable_copy)
	cp $(River1_origin) $(River1_munged)
	cp $(SharesManager1_origin) $(SharesManager1_munged)
	patch -d $(MUNGED_DIR) < $(PATCH)
# mv $(Administrable_munged) $(Administrable_origin)
# mv $(River1_munged) $(River1_origin)

# munged:  $(wildcard $(CONTRACTS_DIR)/*.sol) $(PATCH)
# 	rm -rf $@
# 	cp -r $(CONTRACTS_DIR) $@
# 	patch -p0 -d $@ < $(PATCH)

record:
	$(info Delete old contents of the patch and record changes file by file)
	> $(PATCH)
# diff -uN $(Administrable_origin) $(Administrable_munged) | sed 's+\$(Administrable_origin)/++g' | sed 's+$(Administrable_munged)++g' > $(PATCH)
	diff -uN $(River1_origin) $(River1_munged) | sed 's+\$(River1_origin)/++g' | sed 's+$(River1_munged)++g' >> $(PATCH)
	diff -uN $(SharesManager1_origin) $(SharesManager1_munged) | sed 's+\$(SharesManager1_origin)/++g' | sed 's+$(SharesManager1_munged)++g' >> $(PATCH)

# record:
# 	diff -ruN $(CONTRACTS_DIR) $(MUNGED_DIR) | sed 's+\.\./contracts/++g' | sed 's+munged/++g' > $(PATCH)

# revert:
#	cp $(Administrable_origin) $(Administrable_munged)
#	cp $(River1_origin) $(River1_munged)
#	mv $(Administrable_copy) $(Administrable_origin)
#	mv $(River1_copy) $(River1_origin)

clean:
	git clean -fdX
	touch $(PATCH)