# Rocket Mount

As montarias que ainda faltam, **ordenadas da mais fácil para a mais difícil**, com uma ficha
explicando como cada uma se pega. Para World of Warcraft: Midnight (12.x).

> 🇺🇸 [Read in English](README.md) — o inglês é a versão de referência deste documento.

⚠️ **Ainda não publicado.** O addon está em desenvolvimento. Tudo que ele escreve na tela agora
passa por `Locales/`, com o inglês como idioma-chave e a tradução para o português ao lado — que
era o que faltava para ele entrar na esteira de publicação.

## Por que existe

Catálogo de montaria já existe, e é bom. O que nenhum deles responde é a pergunta que a gente
realmente tem ao sentar para coletar: **qual eu vou buscar primeiro?**

Os addons existentes ordenam por raridade — do mais raro primeiro, que é o oposto de um ponto de
partida — e respondem por zona, quando você está com o mapa do mundo aberto. O Rocket Mount faz
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
| **Na sorte — chance boa** | liberada, e 1% ou mais |
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
| Se a missão que dá a montaria foi feita | `C_QuestLog.IsQuestFlaggedCompleted` |
| **O que o jogo diz que é exigido** | o tooltip do próprio item, via `C_TooltipInfo` |
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
personagem não tem"*. Entre uma vez com cada alt para eles aparecerem; `/rmt who` mostra o que
está anotado.

É livro-caixa, não leitura ao vivo, e ele diz isso: tudo ali era verdade quando aquele personagem
entrou pela última vez.

## Quando algo na sua frente larga montaria

Passe voando e veja no minimapa, mire, passe o mouse, ou deixe o raro gritar quando nasce: um
painel pequeno diz quem é o raro, quais montarias que você não tem podem vir dele e **a chance de
cada uma**. No chat vem um link que aponta a seta do mapa para o raro.

Não é um segundo escaneador de raros. O SilverDragon avisa que há um raro; este avisa que há
**uma montaria que falta para você**, e qual. Raro cuja montaria você já tem não diz nada. As que
saíram do jogo também não — isso seria provocação. E o raro que você já saqueou hoje também fica
quieto: ele volta a nascer, mas não larga nada para você até o reset. E o aviso só fala no mundo
aberto: dentro de masmorra, raide, imersão e cenário ele fica em silêncio.

As chances vêm das contagens de queda do Wowhead, embutidas no addon (`Data/MobDrops.lua`), então
nenhum outro addon é necessário. São amostras, não as taxas da Blizzard: vão arredondadas em dois
algarismos, e um `~` marca as que se apoiam em menos de dez quedas. Desliga com `/rmt warn` ou pela
caixa nas opções.

## A busca

A caixa no alto da janela filtra enquanto você digita, e ela **não** procura só no nome da
montaria. A que cai do Fyrakk se chama *Anu'relos, Flame's Guidance* — a palavra "Fyrakk" não
aparece no nome dela em lugar nenhum, então procurar só por nome falharia exatamente no caso que
faz a pessoa querer uma busca.

Ela procura em tudo que o addon sabe da montaria: nome, o texto de origem da Blizzard, o chefe,
o vendedor, a zona e a facção. Acento é ignorado, e todas as palavras que você digitar precisam
bater — digitar mais estreita, que é o que digitar mais deveria fazer.

## As que saíram do jogo

Promoções encerradas, montarias de jogo de cartas, conquistas aposentadas. Ninguém mais consegue,
então elas ficam fora da lista — numa lista cujo assunto é *por onde começar*, montaria que
ninguém consegue é a pior linha possível. `/rmt gone` (ou a opção) liga, e aí elas aparecem
por último, em faixa própria e sem estimativa de esforço: não é difícil, é impossível.

## Por que não existe uma base curada aqui

A correção óbvia para "o catálogo não sabe deste requisito" é escrever uma base própria. Não
escrevemos, e o motivo é o modo de falha: **entrada curada errada erra em silêncio**, para
sempre, e é o addon falando com confiança de algo que ninguém verificou. O addon inteiro existe
para não afirmar mais do que consegue provar.

O jogo já sabe. Passe o mouse no item da montaria e o tooltip diz, no seu idioma, *"Requer
Exaltado com <facção>"* ou *"Requer <conquista>"*. O `C_TooltipInfo` entrega essas mesmas linhas
como dado, e o addon as lê: cobrem toda montaria que tem item, continuam certas depois do
próximo patch sem ninguém manter, já vêm traduzidas, e quando elas não dizem nada esse silêncio
é a verdade — e não um buraco na planilha de alguém.

Os padrões de "Requer ..." são montados a partir das globais do próprio cliente, nunca escritos
num idioma — um "Requer" cravado quebraria em todo cliente que não é ptBR, em silêncio.

## O que não dá para responder: "essa missão está disponível?"

Quando a montaria vem de missão, o addon diz se **você já a concluiu**, e se outro personagem seu
concluiu. Ele não consegue dizer se você pode *pegá-la* — se alguma missão anterior, reputação ou
nível ainda está no caminho.

Não é omissão: o cliente não expõe pré-requisito de missão para addon nenhum. Dos addons
instalados aqui, 67 chamam `IsQuestFlaggedCompleted` e **nenhum** chama nada sobre pré-requisito,
porque não há o que chamar. Os que mostram cadeia de missão, como o Zygor, embarcam base
própria feita à mão.

"Não concluída" já responde o que importa — tem coisa no caminho — sem fingir saber quantos
passos faltam.

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
| `/rmt sources` | limpa o filtro de fonte |
| `/rmt minimap` | mostra ou esconde o botão do minimapa |
| `/rmt faction [mine\|horde\|alliance]` | filtra por facção |
| `/rmt who` | os personagens anotados e quantas reputações cada um tem |
| `/rmt gone` | mostra ou esconde as que saíram do jogo |
| `/rmt search <texto>` | procura por nome, chefe, zona ou vendedor |
| `/rmt expansion [nome]` | filtra por expansão |
| `/rmt warn` | liga ou desliga o aviso de bicho |
| `/rmt i18n` | confere os rótulos que vêm do jogo |
| `/rmt debug [nome]` | o que o addon conseguiu ler, de tudo ou de uma montaria |

## Apoio

Estes addons são gratuitos e vão continuar sendo. Se eles te poupam tempo toda sessão, há duas
formas de ajudar, e as duas pagam a mesma coisa — as horas de manter tudo em dia a cada patch:

- **[Ko-fi](https://ko-fi.com/ottorocket)** — uma contribuição avulsa, de qualquer valor, **sem
  precisar de conta**.
- **[GitHub Sponsors](https://github.com/sponsors/otaviohonorio)** — recorrente, se preferir.

Não fazer nem uma coisa nem outra não te custa nada aqui. Um bom relato de defeito vale o mesmo.

## Licença

MIT — ver `LICENSE`.
