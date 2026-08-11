# Relatorio de Alinhamento de Traducoes

**Status**: Atualizado
**Ultima revisao**: 2026-08-11

Total de chaves no template ingles: **1454**

| Idioma | Chaves traduzidas | Cobertura | Chaves faltantes | Chaves extras |
|--------|-------------------|-----------|------------------|---------------|
| AR | 1421 | 97.7% | 33 | 0 |
| BN | 1421 | 97.7% | 33 | 0 |
| DE | 1421 | 97.7% | 33 | 0 |
| ES | 1421 | 97.7% | 33 | 0 |
| FR | 1421 | 97.7% | 33 | 0 |
| HI | 1421 | 97.7% | 33 | 0 |
| IT | 1421 | 97.7% | 33 | 0 |
| JA | 1421 | 97.7% | 33 | 0 |
| KO | 1421 | 97.7% | 33 | 0 |
| PT | 1429 | 98.3% | 25 | 0 |
| RU | 1421 | 97.7% | 33 | 0 |
| ZH | 1421 | 97.7% | 33 | 0 |
| UR | 1421 | 97.7% | 33 | 0 |

## Observacoes

- Os 32 valores do issue #102 (pesquisa e grupos de navegacao de Settings) estao traduzidos em todos os idiomas.
- As lacunas restantes sao pre-existentes (chaves de arquivos e gestos de abas) e ficam deferidas para o issue #103 ja na fila.
- Nao rode `dart tool/i18n/generate_arb.dart` globalmente enquanto `arb_strings.dart` estiver desatualizado; esse fluxo e destrutivo para chaves mais novas.
- Para novas traducoes, use o fluxo seguro do projeto: gerar payload de chaves faltantes, traduzir, e mesclar de volta com `tool/i18n/merge_back_translations.py`.
