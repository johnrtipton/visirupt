.PHONY: verify deploy
verify:
	uv run --no-project python scripts/verify.py
	bash -n deploy.sh
	node --check static/interactive.js
	cd polls && uv run --no-project python -m unittest -v test_server.py
deploy:
	./deploy.sh
