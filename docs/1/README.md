# 1. Kobold Trial

## Setup
- 6 kobolds: 3 fêmeas, 3 machos
- 1 região isolada com campo frutífero
- Cada kobold vive 80 dias

## Estados internos
- `hunger` — sobe com tempo, cai ao comer
- `rest` — sobe acordado, cai ao dormir
- `social` — sobe com proximidade, cai com isolamento

## Frutas
- Regeneram por reprodução
- Podem ser plantadas por kobolds
- Podem ser extintas se consumidas antes de reproduzir
- Efeitos possíveis: veneno, mais energia, menos energia
- Efeito desconhecido até ser comido

## Aprendizado
- Kobolds nascem sem saber comer — aprendem por experiência ou observação
- Comer registra `{tipo, efeito}` na memória
- Observar outro passando mal registra `{tipo, :ruim}` na memória
- Ensino: transmissão direta de memória entre kobolds com alto score social

## Traits adquiridos por comida
- Resistência a veneno
- Energia máxima aumentada
- Recuperação no sono aumentada

## Reprodução
- Requer: sexos diferentes, score social alto entre os dois, hunger baixo
- Gestação: 10 dias
- Filho nasce com mix aleatorizado dos traits dos pais
- Traits podem ser herdados, ensinados, ou aprendidos por observação