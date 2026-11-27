## Escopo

- Gate/tarefa:
- O que muda:
- O que não muda:

## Evidência (sem PII)

Anexe comandos e resultados. Use conta sintética; nunca inclua nome, e-mail, UID, token ou dados de criança reais.

- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — total e falhas
- [ ] `backend/functions`: `npm test`
- [ ] `backend/test/rules`: `npm test`
- [ ] Smoke/emulador ou ambiente real — comando e resultado
- [ ] Build Android (debug/release) quando aplicável
- [ ] App Check: comportamento verificado quando aplicável
- [ ] Evidências anexadas (logs/prints) sem PII

## Risco e rollback

- Risco:
- Rollback:
- Feature flag / compra desabilitada:

## Checklist

- [ ] PR pequena e focada em um comportamento
- [ ] Sem secrets, chaves ou credenciais no diff
- [ ] Sem dados infantis/PII em logs, prints ou analytics
- [ ] ADR incluído se mudar auth, pagamento, entitlement ou dados infantis
- [ ] Compatibilidade com clientes antigos avaliada
- [ ] `main` não foi alvo de push direto
