.PHONY: verify deploy
verify:
	uv run --no-project python scripts/verify.py
	bash -n deploy.sh
deploy:
	./deploy.sh
