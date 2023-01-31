print-%: FORCE
	@echo "$*" = "$($*)"

dummy: FORCE
	@echo "Please specify a target." && false

.PHONY: FORCE

FORCE:

include applications/*.mk
