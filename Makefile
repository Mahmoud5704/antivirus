.DEFAULT_GOAL := anti
.PHONY: pre anti restore cron openanti openanticron openrest openmake

pre:
	mkdir -p restore

anti: pre
	./antivirusd.sh original restore 2

restore: pre
	./restore.sh original restore

cron: pre
	./antivirus-cron.sh original restore

openanti:
	nano antivirusd.sh

openanticron:
	nano antivirus-cron.sh

openrest:
	nano restore.sh

openmake:
	nano Makefile
