ghcid-test:
	ghcid \
		--command "stack ghci hRaft:lib hRaft:test:hRaft-test  --ghci-options=-fobject-code" --test "main"

lint:
	hlint lint .

.PHONY: ghcid-test lint
