# Rocket Mounts

As montarias que ainda faltam, **ordenadas da mais fácil para a mais difícil**, com uma ficha
explicando como cada uma se pega. Para World of Warcraft: Midnight (12.x).

> 🇺🇸 [Read in English](README.md) — o inglês é a versão de referência deste documento.

⚠️ **Ainda não publicado.** O addon está em desenvolvimento e a interface dele está escrita
direto em português. Precisa de `Locales/` com o inglês como idioma-chave antes de entrar na
esteira de publicação.

## Por que existe

Catálogo de montaria já existe, e é bom. O que nenhum deles responde é a pergunta que a gente
realmente tem ao sentar para coletar: **qual eu vou buscar primeiro?**

Os addons existentes ordenam por raridade — do mais raro primeiro, que é o oposto de um ponto de
partida — e respondem por zona, quando você está com o mapa do mundo aberto. O Rocket Mounts faz
a pergunta inversa e responde numa lista ordenada só.

## Como a ordem é decidida

Cada montaria cai numa faixa por uma **regra declarada**, e cada linha mostra **o número que a
pôs ali**. Discordar do critério é possível olhando a lista.

| Faixa | Regra |
|---|---|
| **Garantidas — é só ir pegar** | requisito de acesso conhecido e cumprido, e nada por sorte |
| **Confira no vendedor** | o preço cabe, mas nenhum requisito de acesso é conhecido |
| **Garantidas — quase liberadas** | 75% ou mais do requisito |
| **Garantidas — a meio caminho** | 25% ou mais |
| **Na sorte — chance boa** | liberada, e 1 em 100 ou melhor |
| **Caminho longo** | chance pior, ou requisito ainda no começo |
| **Sem estimativa** | nenhum catálogo instalado sabe medir esta |

Duas distinções sustentam tudo:

**Requisito não é aquisição.** Reputação, moeda e conquista dizem se você *pode tentar*. O que
entrega a montaria é outra coisa — comprar do vendedor entrega, matar um chefe com 1 em 100 de
chance não entrega. Então "é só ir pegar" exige aquisição determinística; com taxa de queda no
meio, o requisito no máximo libera o farm.

**Acesso não é preço.** Ouro quase nunca é o que trava alguém — o que trava é reputação,
conquista, nível de guilda, classificação. Montaria de que só se sabe o preço vai para "Confira
no vendedor", que promete exatamente o que dá para provar.

## De onde vêm os dados

| Dado | Fonte |
|---|---|
| O que falta, tipo de fonte, o texto do próprio jogo sobre como pega | `C_MountJournal` |
| Progresso de reputação e renome | `C_Reputation`, `C_MajorFactions` |
| Moeda, ouro e item no bolso | `C_CurrencyInfo`, `C_Item`, `GetMoney` |
| Progresso parcial de conquista | `GetAchievementCriteriaInfo` |
| Taxa de queda, coordenada, facção exigida | `MCL_GUIDE` (do addon MCL) |
| Percentual de jogadores que têm a montaria | `MountsRarity-2.0` (dentro do MountJournalEnhanced) |

Os dois últimos são **dependências opcionais**: sem eles a janela abre igual e o rodapé diz em
vermelho o que deixou de estar disponível. O addon de propósito não recria um catálogo que já
existe e é bem mantido — ele entra com o ranqueamento.

Tudo sobre o **seu** progresso vem da API, que é exata e sempre atual. Cada linha de reputação
diz se o progresso vale para a conta ou só para o personagem conectado, pelo nome.

## Qual dos seus personagens tem

Reputação é lida do personagem conectado — é tudo o que a API responde. Parte das facções virou
reputação de conta no War Within, e a linha diz de qual tipo é, pelo nome: *"reputação da conta"*
ou *"só deste personagem (Nome)"*.

Para as que são por personagem, o addon mantém um livro-caixa: toda vez que um personagem entra
no jogo, ele anota onde aquele personagem está com as facções que alguma montaria pede. Aí uma
montaria que você não pode comprar aqui diz quem pode — *"Ottozinho tem (Exaltado) — este
personagem não tem"*. Entre uma vez com cada alt para eles aparecerem; `/rmt quem` mostra o que
está anotado.

É livro-caixa, não leitura ao vivo, e ele diz isso: tudo ali era verdade quando aquele personagem
entrou pela última vez.

## As que saíram do jogo

Promoções encerradas, montarias de jogo de cartas, conquistas aposentadas. Ninguém mais consegue,
então elas ficam fora da lista — numa lista cujo assunto é *por onde começar*, montaria que
ninguém consegue é a pior linha possível. `/rmt sumidas` (ou a opção) liga, e aí elas aparecem
por último, em faixa própria e sem estimativa de esforço: não é difícil, é impossível.

## Lacuna conhecida

**A trava de tentativa não é modelada.** Uma queda de 1 em 100 num chefe com trava semanal e uma
de 1 em 100 num bicho sem trava estão separadas por anos, e hoje caem na mesma faixa. Nem a API
nem nenhum catálogo instalado guarda o período de trava por montaria, então a linha mostra o
método e deixa o julgamento com você. Nenhuma estimativa foi inventada para tapar o buraco.

## Como se usa

| Comando | O quê |
|---|---|
| `/rmt` | abre e fecha a lista |
| `/rmt top <n>` | quantas linhas a lista mostra |
| `/rmt fontes` | limpa o filtro de fonte |
| `/rmt minimapa` | mostra ou esconde o botão do minimapa |
| `/rmt faccao [minha\|horda\|alianca]` | filtra por facção |
| `/rmt quem` | os personagens anotados e quantas reputações cada um tem |
| `/rmt sumidas` | mostra ou esconde as que saíram do jogo |
| `/rmt debug [nome]` | o que o addon conseguiu ler, de tudo ou de uma montaria |

## Licença

MIT — ver `LICENSE`.
