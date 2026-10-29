-- RocketMount | Locales/ptBR.lua
-- Overrides what enUS.lua left. A key absent here is NOT a hole: it falls to the
-- game's label (when `FROM_GAME` covers it) or to the key itself, which is already the English text.
--
-- The project's rule for this file: correct Portuguese, no slang. The game's own jargon
-- stays (renome, exaltado, raro) because it is the vocabulary the player already uses.
local ADDON, ns = ...

if GetLocale() ~= "ptBR" then return end

local L = ns.L

--------------------------------------------------------------------------------
-- As faixas da lista
--------------------------------------------------------------------------------
-- The tier's name fits in ~36 letters (`TIER_TITLE_WIDTH` in `Window.lua` reserves 230px at
-- 12pt). Past that, it crosses the list's border -- and the harness counts LETTERS, not bytes,
-- precisely because of the accents.
L["Guaranteed — just go get it"]  = "Garantidas — é só ir pegar"
L["Guaranteed — nearly unlocked"] = "Garantidas — quase liberadas"
L["Guaranteed — halfway there"]   = "Garantidas — a meio caminho"
L["Down to luck — good odds"]     = "Na sorte — boa chance"
L["Long road"]                    = "Caminho longo"
L["Not confirmed"] = "Sem confirmação"
L["No estimate"]                  = "Sem estimativa"
L["Cannot be obtained any more"]  = "Não podem mais ser obtidas"

L["requirement met and checked"]        = "requisito cumprido e conferido"
L["a little left on the requirement"]   = "falta pouco do requisito"
L["road already walked"]                = "caminho já percorrido"
L["1% or better"]                       = "1% ou mais"
L["bad odds, or a distant requirement"] = "chance baixa ou requisito distante"
L["open the vendor to confirm"] = "abra o vendedor para confirmar"

-- The validation before the list (Core.lua, Window.lua).
L["Checking every mount for this character…"] = "Conferindo cada montaria para este personagem…"
L["%d of %d items loaded"] = "%d de %d itens carregados"
L["waiting for the collection data"] = "esperando os dados da coleção"
L["no data to estimate from"]           = "sem dado para estimar"
L["left the game"]                      = "saiu do jogo"

--------------------------------------------------------------------------------
-- The number on the right and the phrase that explains the position
--------------------------------------------------------------------------------
L["ready to grab"] = "pode pegar"

L["Not unlocked yet — %s"] = "Falta liberar — %s"
L["requirement not met"]   = "requisito não cumprido"
L[" (and %d more)"]        = " (e mais %d)"
L["  ·  then, a %s chance"] = "  ·  depois, chance de %s"
L["  ·  guild vendor: asks for reputation and an achievement OF THE GUILD, which I cannot read"] =
    "  ·  vendedor de guilda: exige reputação e conquista DA GUILDA, que eu não leio"
L["  ·  there may be a requirement I cannot read"] =
    "  ·  pode haver requisito que eu não leio"
L["  ·  %s missing"] = "  ·  faltam %s"
L["  ·  and %d more requirement(s)"] = "  ·  e mais %d requisito(s)"
L["%s chance"] = "chance de %s"
-- O separador decimal da porcentagem de chance (0,5%). A chave e o ponto do ingles.
L["."] = ","

--------------------------------------------------------------------------------
-- Nome das fontes (plano B: o jogo traduz `BATTLE_PET_SOURCE_<n>` sozinho)
--------------------------------------------------------------------------------
L["Unknown"]           = "Desconhecida"
L["Drop"]              = "Saque"
L["Quest"]             = "Missão"
L["Vendor"]            = "Vendedor"
L["Profession"]        = "Profissão"
L["Pet Battle"]        = "Batalha de mascotes"
L["Achievement"]       = "Conquista"
L["World Event"]       = "Evento mundial"
L["Promotion"]         = "Promoção"
L["Trading Card Game"] = "Jogo de cartas"
L["Shop"]              = "Loja"
L["Discovery"]         = "Descoberta"

--------------------------------------------------------------------------------
-- Reputation, quest and achievement
--------------------------------------------------------------------------------
L["account-wide reputation"]  = "reputação da conta"
L["this character only (%s)"] = "só deste personagem (%s)"
L["%s: %s — this character does not have it"] = "%s: %s — este personagem não tem"
L["%s: no reputation with this faction on this character"] =
    "%s: nenhuma reputação com esta facção neste personagem"

-- "renome 25 de 5" IS NOT A PHRASE: the "X de Y" form only works while X is walking towards Y.
-- Done is said as done. (The user's question: "eu tenho 25 e precisa de 5?")
L["%s: renown %d reached (you are at %d)"]   = "%s: renome %d alcançado (você está em %d)"
L["%s: renown %d of %d"]                     = "%s: renome %d de %d"
L["%s: %s of %s to the next cache"]          = "%s: %s de %s para o próximo baú"
L["%s: asks for %s, which I cannot measure"] = "%s: exige %s, que eu não sei medir"
L["%s: already %s%s"]      = "%s: já está %s%s"
L["%s: rank reached (%s)"] = "%s: grau alcançado (%s)"
L["%s: %s of %s (%s)"]     = "%s: %s de %s (%s)"
L["at the standing"]       = "no nível"
L["%s: %s of %s to %s%s"]  = "%s: %s de %s para %s%s"
L["the standing"]          = "o nível"

L["%s  ·  %s missing"]  = "%s  ·  faltam %s"
L["%s  ·  you have it"] = "%s  ·  você tem"
L["item %d"]            = "item %d"

L['Quest "%s": completed']                  = 'Missão "%s": concluída'
L["  —  already done on another character"] = "  —  já feita em outro personagem"
L['Quest "%s": not completed%s%s']          = 'Missão "%s": não concluída%s%s'
L['Achievement "%s": not completed']        = 'Conquista "%s": não concluída'

L["Guild vendor: asks for Exalted with the guild and, in most cases, an achievement OF THE GUILD"] =
    "Vendedor de guilda: exige Exaltado com a guilda e, quase sempre, uma conquista DA GUILDA"

--------------------------------------------------------------------------------
-- Who has the reputation (the ledger)
--------------------------------------------------------------------------------
L["%s has it (%s)"]             = "%s tem (%s)"
L["on %s"] = "em %s"
L["%s: %s is already %s — buy it on that character"] = "%s: %s já está %s — compre com esse personagem"
L["%s: %s is at %s of %s to %s — the closest of your characters"] = "%s: %s está em %s de %s para %s — o mais perto entre os seus personagens"
L["%s: %s is %s — the closest of your characters"] = "%s: %s está %s — o mais perto entre os seus personagens"
L["on this character, little is left for %d mount(s):"] = "com este personagem, falta pouco para %d montaria(s):"
L["%s has it (%s) and %d more"] = "%s tem (%s) e mais %d"

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------
-- "Todas" and not "Tudo": the label comes from the game (`ALL`), but here it agrees with "fontes", which
-- is feminine plural. This line is exactly the precedence enUS.lua describes -- our
-- choice beats the game's word.

L["Rocket Mount — where to start"] = "Rocket Mount — por onde começar"

-- The development log (/rmt log). It only exists outside the package.
L["the log only exists in development builds."] = "o diário só existe na versão de desenvolvimento."
L["log cleared."] = "diário apagado."
L["log: every line is also printed in chat."] = "diário: cada linha também aparece no chat."
L["log: chat echo off."] = "diário: fora do chat."
L["alert %s; last lines of the log:"] = "aviso %s; últimas linhas do diário:"
L["OFF"] = "DESLIGADO"
L["on"] = "ligado"
L["the development log"] = "o diário de desenvolvimento"

-- The vendor's own verdict (Sources.lua).
L["the vendor sells it to you (seen %s)"] = "o vendedor vende para você (visto em %s)"
L["inside %s"] = "dentro de %s"
L["  ·  %s drops it nearly every time: getting to it is the task"] =
    "  ·  %s dá a montaria quase sempre: o difícil é chegar até lá"
L["  ·  the price is the journal's: the vendor may charge more"] =
    "  ·  o preço é o do diário: o vendedor pode cobrar mais"
L["the vendor does not sell it to you yet (seen %s)"] = "o vendedor ainda não vende para você (visto em %s)"
-- A short date format for "visto em": day/month in Portuguese.
L["%m/%d"] = "%d/%m"

-- The world map (MapPins.lua).
L["Rare"] = "Raro"
L["Elite"] = "Elite"
L["%dd"] = "%dd"
L["%dh"] = "%dh"
L["%dmin"] = "%dmin"
L["Already looted — back in %s"] = "Já saqueado — volta em %s"
L["Appears in %s"] = "Aparece em %s"
L["Appearing now — for %s more"] = "Aparecendo agora — por mais %s"
L["Its route is the line in this colour."] = "A rota dele é a linha desta cor."
L["Appears in %s — from %s to %s"] = "Aparece em %s — das %s às %s"
L["Appearing now — for %s more, until %s"] = "Aparecendo agora — por mais %s, até as %s"
L["%dh %dmin"] = "%dh %dmin"
L["Already looted today"] = "Já saqueado hoje"
L["Click: point the arrow here"] = "Clique: apontar a seta para cá"
L["Alt+click: Wowhead link"] = "Alt+clique: link do Wowhead"
L["Which mount, on Wowhead?"] = "Qual montaria, no Wowhead?"
L["Can drop:"] = "Pode cair:"
-- The type of each place on the map (27/09). They are the labels under the marker and the tooltip's second line.
L["Boss"] = "Chefe"
L["Treasure"] = "Tesouro"
L["Portal"] = "Portal"
L["Starts here"] = "Começa aqui"
L["Delve"] = "Imersão"
L["Ritual Site"] = "Sítio Ritualístico"
L["Horrific Visions"] = "Visões Horrendas"
L["%s and %d more"] = "%s e mais %d"
L["Only during: %s"] = "Só durante: %s"
L["On the minimap"] = "No minimapa"
L["%s: of the event %s, which is ON"] = "%s: do evento %s, que ESTÁ acontecendo"
L["%s: of the event %s, which is not on (no marker)"] = "%s: do evento %s, que não está acontecendo (sem marcador)"
L["%s: Trading Post; the game's landmark is %s, mounts on offer known: %d"] =
    "%s: Posto Comercial; o marco do jogo %s, montarias em oferta conhecidas: %d"
L["on the map"] = "está no mapa"
L["NOT on the map"] = "NÃO está no mapa"
L["Marks the places within the minimap's reach too, each with the symbol of what it is: a rare, a vendor, a treasure. Hover one for the same details as on the world map; click it to point the arrow there."] =
    "Marca também os lugares ao alcance do minimapa, cada um com o símbolo do que é: um raro, um vendedor, um tesouro. Passe o mouse em um para ver os mesmos detalhes do mapa-múndi; clique para apontar a seta para lá."
L["%s: renown %d, and this character is not in this covenant"] =
    "%s: renome %d, e este personagem não é deste pacto"
L["Leads to:"] = "Leva a:"
L["Fishing"] = "Pesca"
L["Other"] = "Outra fonte"
L["Sells:"] = "Vende:"
L["Rewards:"] = "Recompensa:"
L["Mounts here:"] = "Montarias daqui:"
-- The description of the card and the tooltip (27/09).
L["Achievement: %s"] = "Conquista: %s"

-- PLAYERS' TIPS (27/09). Only the labels live here; the text of each tip in Portuguese
-- is in `Locales/ptBR_Tips.lua`, which is GENERATED (tools/gerar_dicas.py) along with the English.
L["Players' tip"] = "Dica de jogadores"
L["Reported by players in %d. The game may have changed since."] =
    "Relatado por jogadores em %d. O jogo pode ter mudado desde então."
L["Reported by players. The game may have changed since."] =
    "Relatado por jogadores. O jogo pode ter mudado desde então."
L["Vendors and quests"] = "Vendedores e missões"
L["Besides the rares, every other place known for a mount you do not have: who sells it, who gives the quest, where the treasure is."] =
    "Além dos raros, todo outro lugar conhecido de uma montaria que você não tem: quem vende, quem entrega a missão, onde está o tesouro."
L["Instance entrances"] = "Entradas de instância"
L["Raid and dungeon entrances, with the mounts that drop inside. The marker steps aside so the game's own entrance icon stays visible."] =
    "As entradas de raide e de masmorra, com as montarias que caem lá dentro. O marcador se afasta para o ícone de entrada do próprio jogo continuar visível."
L["Source names"] = "Nome do tipo"
L["Rare routes"] = "Rota dos raros"
L["%d route(s), drawn with %d dash(es)"] = "%d rota(s), desenhada(s) com %d traço(s)"
L["A rare that patrols gets one marker and a dashed line along where it was seen. The route is an estimate from players' sightings. Unchecked, only the marker is drawn."] =
    "O raro que patrulha ganha um marcador só e uma linha tracejada por onde ele foi visto. A rota é uma estimativa, feita dos avistamentos dos jogadores. Desmarcada, só o marcador é desenhado."
L["Writes Rare, Vendor, Quest, Raid… under each marker. Unchecked, the small symbol on the marker still says it."] =
    "Escreve Raro, Vendedor, Missão, Raide… sob cada marcador. Desmarcada, o pequeno símbolo do marcador continua indicando o tipo."
L["World map"] = "Mapa-múndi"
L["Every source of a mount you do not have, on the world map: the mount's icon, what kind of source it is, and the chance or how much is left when you hover it. A looted rare goes dim."] =
    "Toda fonte de montaria que você não tem, no mapa-múndi: o ícone da montaria, o tipo da fonte e, ao passar o mouse, a chance ou o quanto falta. Raro já saqueado fica apagado."
L["open the world map on a zone first."] = "abra o mapa-múndi numa zona primeiro."
L["map %s (%d): %d place(s) asked for, %d drawn, %d failed."] = "mapa %s (%d): %d lugar(es) pedidos, %d desenhados, %d com falha."
L["    first failure: %s"] = "    primeira falha: %s"
L["what the world map drew, and what failed"] = "o que o mapa-múndi desenhou, e o que falhou"

-- The list's tags (Score.lua). "Drop" stays: it is the term the player uses.
L["Raid"] = "Raide"
L["Dungeon"] = "Masmorra"
L["Renown"] = "Renome"
L["Reputation"] = "Reputação"
L["Trading Post"] = "Posto Comercial"
L["From a promotion outside the game"] = "De uma promoção de fora do jogo"
L["From the Trading Card Game"] = "Do jogo de cartas"
L["Sold in the in-game shop"] = "Vendida na loja do jogo"
L["From the Trading Post, when it is on offer"] = "Do Posto Comercial, quando está em oferta"

-- A lista com colunas (Window.lua).
L["Mount"] = "Montaria"
L["Type"] = "Tipo"
L["Show"] = "Mostrar"
L["Show all"] = "Mostrar todas"
L["Group by type, then %"] = "Agrupar por tipo, depois %"
L["Group by expansion, then %"] = "Agrupar por expansão, depois %"
L["What the percentage means"] = "O que o percentual quer dizer"
L["It is what the mount depends on, and the list is ordered by it."] = "É aquilo de que a montaria depende, e a lista é ordenada por ele."
L["the chance of each attempt"] = "a chance de cada tentativa"
L["how much of it is done"] = "o quanto já está feito"
L["how far to the standing asked for"] = "o caminho até o nível exigido"
L["how far to the renown level asked for"] = "o caminho até o renome exigido"
L['Achievement "%s": %d%% done'] = 'Conquista "%s": %d%% feita'
L["\"?\" means it cannot be measured yet: open the vendor, or there is no data."] =
    "\"?\" quer dizer que ainda não dá para medir: abra o vendedor, ou não há dado."
L["Markers on the map"] = "Marcadores no mapa"
L["errors are NOT being captured on this client."] = "os erros NÃO estão sendo capturados neste cliente."
L["no error captured (capture: %s)."] = "nenhum erro capturado (captura: %s)."
L["%d error(s) captured, %d occurrence(s):"] = "%d erro(s) capturado(s), %d ocorrência(s):"
L["name, boss, zone, vendor"] = "nome, chefe, zona, vendedor"
L["Set map pin"] = "Marcar no mapa"
L["Pick a mount in the list to see how it is obtained."] =
    "Escolha uma montaria na lista para ver como obtê-la."

L["How to get it"] = "Como obter"
L["Chance"]        = "Chance"
L["Expansion"]     = "Expansão"
L["Faction"]       = "Facção"
L["Horde only"]    = "Só para a Horda"
L["Alliance only"] = "Só para a Aliança"

L["Requirements — %d of %d missing"]    = "Requisitos — faltam %d de %d"
L["Requirements — all met"]             = "Requisitos — todos cumpridos"
L["Who has it, from what was recorded"] = "Quem tem, pelo que ficou anotado"

L["Heads up"] = "Atenção"
L["The requirement above only UNLOCKS the attempt. Once met, the mount still depends on luck."] =
    "O requisito acima só LIBERA a tentativa. Depois de cumprido, a montaria ainda depende da sorte."

L["Why check"] = "Por que conferir"
L["Guild vendor. These ask for reputation with your guild AND an achievement OF THE GUILD — and the achievement is the part I cannot read. The price shown in the requirements is only part of what it costs."] =
    "Vendedor de guilda. Estas exigem reputação com a sua guilda E uma conquista DA GUILDA — e é "
    .. "a conquista que eu não consigo ler. O preço que aparece nos requisitos é só uma parte do "
    .. "que ela custa."
L["Of what I can read, only the price shows up on this mount — and price is almost never what blocks. There may be an achievement, a guild level or a rating in the way, and those I do not read."] =
    "Do que eu consigo ler, só o preço aparece nesta montaria — e preço quase nunca é o que "
    .. "impede. Pode haver conquista, nível de guilda ou classificação no caminho, e isso eu não "
    .. "leio."
L[" And where its vendor is, I do not know."] =
    " E onde fica o vendedor dela, eu não sei."

L["Where"]                    = "Onde"

L["arrow pointed at %s."] = "seta apontada para %s."
L["the mount"]            = "a montaria"

L["%d mounts missing"]      = "%d montarias faltando"
L["Next in line:"]          = "Próxima da fila:"
L[" (filtered from %d)"]    = " (filtradas de %d)"
L['nothing found for "%s"'] = 'nada encontrado para "%s"'

--------------------------------------------------------------------------------
-- O aviso de raro
--------------------------------------------------------------------------------
L["and %d more"]                    = "e mais %d"
L["this map does not accept pins."] = "este mapa não aceita marcação."

-- ⛑ "marcar onde vi" LEFT (22/09). The link marked the player's feet, and not the rare -- the report
-- came from Luaprata, with the arrow nailed in the capital for a rare of another zone. Now it points
-- at the coordinate the catalogue keeps, so the label came to say what it does.
L["point me at this rare"] = "apontar para o raro"
L["the rare"]              = "o raro"
L["|cffffff00%s|r can drop: %s%s"]      = "|cffffff00%s|r pode dar: %s%s"

--------------------------------------------------------------------------------
-- The options panel
--------------------------------------------------------------------------------
L["Only what I can get"] = "Só o que posso pegar"
L["A mount from the other faction or another class leaves the list. Uncheck to see the whole collection."] =
    "Montaria de outra facção ou de outra classe sai da lista. Desmarque para ver a coleção "
    .. "inteira."

L["Minimap button"] = "Botão do minimapa"
L["The button opens the list with a click and the options with a right-click. Its tooltip already shows the next mount in line."] =
    "O botão abre a lista com um clique e as opções com o botão direito. A dica dele já mostra a "
    .. "próxima montaria da fila."

L["Rare alert"] = "Aviso de raro"
-- (21/10) the achievement-style alert when a mount is learned (Toast.lua)
L["Mount achievement"] = "Conquista de montaria"
L["When you learn a mount, an alert like the game's achievement one shows its name and icon. It is the addon's, not a real achievement."] =
    "Ao aprender uma montaria, um aviso igual ao de conquista do jogo mostra o nome e o ícone dela. É do addon, não é uma conquista de verdade."
L["Click: close"] = "Clique: fechar"
L["shows the alert of a new mount, to see how it looks"] = "mostra o aviso de montaria nova, para ver como fica"
L["no mount to show the alert with."] = "nenhuma montaria para mostrar o aviso."
L["A rare, elite or world boss that drops a mount you do not have: the alert shows who it is, the mount and the chance. Open world only, and quiet once you looted it."] =
    "Raro, elite ou chefe do mundo que pode dar uma montaria que você não tem: o aviso diz quem é, "
    .. "a montaria e a chance. Só no mundo aberto, e fica em silêncio depois que você o saqueia."

L["Removed mounts"] = "Montarias removidas"
L["Also lists the mounts that left the game: closed promotions, trading card game mounts and retired achievements. They cannot be obtained any more, so they stay out of the list by default."] =
    "Lista também as montarias que saíram do jogo: promoções encerradas, montarias de jogo de cartas e conquistas aposentadas. Elas não podem mais ser obtidas, então ficam fora da lista por padrão."

--------------------------------------------------------------------------------
-- The commands
--------------------------------------------------------------------------------
L["the options panel has not registered yet."] = "o painel de opções ainda não foi registrado."
L["the list shows every missing mount — the row cap was removed in 0.10.0."] =
    "a lista mostra todas as montarias que faltam — o limite de linhas saiu na 0.10.0."
L["minimap button hidden."] = "botão do minimapa escondido."
L["minimap button shown."]  = "botão do minimapa visível."

L["expansion: all."] = "expansão: todas."
L["expansion: %s"]   = "expansão: %s"
L["expansion not recognized. These exist:"] = "expansão não reconhecida. As que existem:"

L["search cleared."]     = "busca limpa."
L['searching for "%s".'] = 'buscando por "%s".'

L["mount sighting alert on."]  = "aviso de raro ligado."
L["mount sighting alert off."] = "aviso de raro desligado."

L["also showing the ones that left the game."] = "mostrando também as que saíram do jogo."
L["hiding the ones that left the game."]       = "escondendo as que saíram do jogo."

L["only what this character can get"] = "só o que este personagem pode pegar"
L["all"]         = "todas"
L["faction: %s"] = "facção: %s"

L["%d character(s) recorded. The ledger is written as each one logs in — log in with your alts once so they show up here."] =
    "%d personagem(ns) anotado(s). Cada um é anotado quando entra no jogo — entre "
    .. "uma vez com cada um dos outros para que apareçam aqui."
L["    %s%s  —  %d reputation(s) recorded, seen on %s"] = "    %s%s  —  %d reputações anotadas, visto em %s"
L["%m/%d/%Y"] = "%d/%m/%Y"
L["A character that no longer exists: /rmt forget Name"] = "Personagem que não existe mais: /rmt esquecer Nome"
L["more than one character is called %s: write it with the realm, Name-Realm."] =
    "mais de um personagem se chama %s: escreva com o reino, Nome-Reino."
L["which character? /rmt who lists them; then /rmt forget Name"] =
    "qual personagem? /rmt quem lista todos; depois /rmt esquecer Nome"
L["%s is out of the records: reputations, rares looted and what the vendors said."] =
    "%s saiu dos registros: reputações, raros saqueados e o que os vendedores disseram."
L["%s is the character you are playing: it would be recorded again right away."] =
    "%s é o personagem com que você está jogando: seria anotado de novo na hora."
L["takes a character that no longer exists out of the records"] = "tira dos registros um personagem que não existe mais"
L["%s no longer exists"] = "%s não existe mais"
L["The markers of the mounts you are missing are on the map."] = "As marcações das montarias que faltam estão no mapa."
L["Map button"] = "Botão no mapa"
L["A round button with a horseshoe on the world map, in the column of the map's own buttons at the top right. Its menu hides every marker of Rocket Mount, for when you need the map clean, shows only the mounts you are missing, or the collected ones too, with a gold ring."] =
    "Um botão redondo com uma ferradura no mapa-múndi, na coluna dos botões do próprio mapa, no alto à direita. O menu dele esconde todas as marcações do Rocket Mount, para quando você precisa do mapa limpo, mostra só as montarias que faltam ou também as já coletadas, com um aro dourado."
L['Quest "%s": %d of the %d quests that lead to it done'] = 'Missão "%s": %d das %d missões que levam a ela feitas'
L['  ·  next: "%s"'] = '  ·  a próxima: "%s"'
L["By difficulty, as players measured it:"] = "Por dificuldade, como os jogadores mediram:"
L["Chests of a difficulty not identified: %s"] = "Baús de dificuldade não identificada: %s"
L["%s to %s"] = "%s a %s"
L["The number of the list is of all the difficulties together."] = "O número da lista é o de todas as dificuldades juntas."
L["Last seen on %s"] = "Visto pela última vez em %s"
L["The game does not tell an addon that a character was deleted, renamed or moved. Click to take it out of what Rocket Mount recorded."] =
    "O jogo não avisa um addon de que um personagem foi excluído, renomeado ou transferido. Clique para tirá-lo do que o Rocket Mount anotou."
L["Take %s out of the records of Rocket Mount?|n|nFor a character that was deleted, renamed or moved. One that still exists is recorded again the next time it logs in."] =
    "Tirar %s dos registros do Rocket Mount?|n|nPara personagem que foi excluído, renomeado ou transferido. O que ainda existe é anotado de novo na próxima vez em que entrar no jogo."

L["source filter cleared: every source is back."] =
    "filtro de fonte limpo: todas as fontes voltam a aparecer."

L['no missing mount has "%s" in its name.'] = 'nenhuma montaria que falta tem "%s" no nome.'
L["%d mounts missing on this character:"] = "%d montarias faltando neste personagem:"

L["locale %s, %d game label(s):"]          = "idioma %s, %d rótulo(s) do jogo:"
L["%d game label(s) are not usable here."] = "%d rótulo(s) do jogo não servem aqui."

L["commands:"] = "comandos:"
L["opens and closes the list"]                  = "abre e fecha a lista"
L["clears the source filter"]                   = "limpa o filtro de fonte"
L["filters by faction"]                         = "filtra por facção"
L["shows or hides the ones that left the game"] = "mostra ou esconde as que saíram do jogo"
L["turns the mount sighting alert on or off"]   = "liga e desliga o aviso de raro"
L["searches by name, boss, zone or vendor"]     = "procura por nome, chefe, zona ou vendedor"
L["filters by expansion"]                       = "filtra por expansão"
L["the characters recorded and how many reputations each one has"] =
    "os personagens anotados e quantas reputações cada um tem"
L["shows or hides the minimap button"]     = "mostra ou esconde o botão do minimapa"
L["options"]                               = "opções"
L["checks the labels taken from the game"] = "confere os rótulos que vêm do jogo"
L["what the addon managed to read"]        = "o que o addon conseguiu ler"
L["everything it knows about one mount"]   = "tudo o que ele sabe sobre uma montaria"

-- The rares' loot frequency (Sighting.lua, 25/09)
L["Loot: once a day"] = "Saque: 1 vez por dia"
L["Loot: once a week"] = "Saque: 1 vez por semana"
L["Loot: every kill"] = "Saque: sem limite (a cada morte)"
L["Loot: every kill, best chance on the day's first"] = "Saque: sem limite (melhor chance na 1ª morte do dia)"
L["Loot: once per character"] = "Saque: 1 vez por personagem"
L["Loot: how often is not known yet"] = "Saque: frequência ainda não conhecida"
L["Already looted this week"] = "Já saqueado nesta semana"

-- The collection counters (Window.lua, 26/09)
L["Collected"] = "Coletadas"
L["%d of %d mounts"] = "%d de %d montarias"
L["Only mounts this character can use count toward it."] = "Só contam as montarias que este personagem pode usar."
L["done"] = "concluída"

-- Donation (Donate.lua, 26/09)
L["Link copied — paste it in your browser."] = "Link copiado — cole no navegador."
L["Thank you for supporting Rocket Mount! Press Ctrl+C to copy the link, then paste it in your browser."] = "Obrigado por apoiar o Rocket Mount! Aperte Ctrl+C para copiar o link e cole no navegador."
L["Click: open the donation link, ready to copy"] = "Clique: abrir o link de doação, pronto para copiar"
L["Support the project"] = "Apoiar o projeto"
L["Report a problem"] = "Relatar um problema"
L["Report a problem on"] = "Relatar um problema em"
L["Click: choose where to report a problem"] = "Clique: escolher onde relatar um problema"
L["Rocket Mount %s — report a problem on %s.|n|nPress Ctrl+C to copy the link, then paste it in your browser. Say what you were doing and what happened."] =
    "Rocket Mount %s — relatar um problema em %s.|n|nAperte Ctrl+C para copiar o link e cole no navegador. Conte o que você estava fazendo e o que aconteceu."

-- The alert's sound (01/10).
L["Play a sound"] = "Tocar um som"
L["Send to TomTom"] = "Enviar ao TomTom"
L["With TomTom installed, the alert also puts the rare's place in it, with its arrow. Without TomTom nothing changes; the pin in the chat is there either way."] =
    "Com o TomTom instalado, o aviso também põe nele o lugar do raro, com a seta dele. Sem o TomTom nada muda; a marcação no chat continua lá do mesmo jeito."
L["A short chime when the alert appears. It is the addon's own: no sound of the game is used."] = "Um toque curto quando o aviso aparece. É do próprio addon: nenhum som do jogo é usado."
L["Sound"] = "Som"
L["Which chime the alert plays. Picking one plays it."] = "Qual toque o aviso usa. Ao escolher um, ele toca."
L["Volume"] = "Volume"
L["How loud the alert's sound is, in five steps. The game's own sound effects volume still applies."] = "O volume do som do aviso, em cinco níveis. O volume de efeitos sonoros do próprio jogo também se aplica."
L["Chime"] = "Sino"
L["Ding"] = "Toque"
L["Three notes"] = "Três notas"
L["Soft"] = "Suave"

-- How to feed the list: the tips in the window (01/10).
L["How to feed the list"] = "Como alimentar a lista"
L["Tips  ·  %d character read"] = "Dicas  ·  %d personagem lido"
L["Tips  ·  %d characters read"] = "Dicas  ·  %d personagens lidos"
L["The list reads the game for the character you are on. What follows is what only you can show it."] =
    "A lista lê o jogo pelo personagem em que você está. O que vem a seguir é o que só você pode mostrar a ela."
L["Enter the game with each of your characters"] = "Entre no jogo com cada um dos seus personagens"
L["The addon reads only the character that is logged in. Each one you enter with is written down, and from then on the list says which of them already has the reputation a mount asks for."] =
    "O addon lê apenas o personagem que está conectado. Cada um com que você entra fica anotado, e a partir daí a lista diz qual deles já tem a reputação que uma montaria pede."
L["Open the vendors that sell mounts"] = "Abra os vendedores que vendem montaria"
L["The vendor is who knows the real price and whether it sells to this character. A mount with \"?\" is waiting for that."] =
    "O vendedor é quem sabe o preço de verdade e se vende para este personagem. Montaria com \"?\" está esperando por isso."
L["Open the Trading Post every month"] = "Abra o Posto Comercial todo mês"
L["Its mounts only enter the list after the game shows what is on offer."] =
    "As montarias dele só entram na lista depois que o jogo mostra o que está em oferta."
L["Loot the rares you kill"] = "Saqueie os raros que você matar"
L["The addon learns how often each rare can drop again, and stops calling you to one that has nothing for you today."] =
    "O addon aprende de quanto em quanto tempo cada raro volta a ter saque, e deixa de indicar um raro que hoje não tem nada para você."
L["A character that no longer exists"] = "Personagem que não existe mais"
L["Deleted, renamed or moved to another realm: click this button and pick it in the list to take it out."] =
    "Apagado, renomeado ou transferido de reino: clique neste botão e escolha o personagem na lista para tirá-lo."
L["this character"] = "este personagem"
L["Click a character that no longer exists to take it out"] = "Clique em um personagem que não existe mais para tirá-lo"
L["Click: the characters read, to take out one that no longer exists"] = "Clique: os personagens lidos, para tirar um que não existe mais"

-- The place of a mount, from the list (02/10).
L["The way in"] = "A entrada"
L["Click: mark it on the map"] = "Clique: marcar no mapa"
L["(click the link to open the map)"] = "(clique no link para abrir o mapa)"
L["%s: %s (this map takes no pin)"] = "%s: %s (este mapa não aceita marcação)"

-- The size of the markers on the world map (02/10).
L["Marker size"] = "Tamanho do marcador"
L["How large the markers are on the world map. 100% is the size of the game's own quest marker."] =
    "O tamanho dos marcadores no mapa-múndi. 100% é o tamanho do marcador de missão do próprio jogo."
L["Size on the minimap"] = "Tamanho no minimapa"
L["How large the markers are on the minimap."] = "O tamanho dos marcadores no minimapa."

-- The note at the foot of the window (02/10).
L["The list and the descriptions are still being improved: suggestions are welcome."] =
    "A lista e as descrições ainda estão em evolução: sugestões são bem-vindas."
L["Suggestions are welcome"] = "Sugestões são bem-vindas"
L["A mount in the wrong place of the list, a place that is missing, a description that is wrong or could say more: tell us, and the next version has it."] =
    "Uma montaria no lugar errado da lista, um local que falta, uma descrição errada ou que poderia dizer mais: conte para nós, e isso entra na próxima versão."
L["Click: where to send it"] = "Clique: para onde enviar"

-- The achievement of a mount, from the list (02/10).
L["Open the achievement"] = "Abrir a conquista"
L["Track"] = "Rastrear"
L["Stop tracking"] = "Parar de rastrear"
L["Click: open the achievement"] = "Clique: abrir a conquista"
L["Right-click: track it"] = "Botão direito: rastrear"
L["Right-click: stop tracking it"] = "Botão direito: parar de rastrear"

-- The Collection tab (02/10).
L["List"] = "Lista"
L["Collection"] = "Coleção"
L["Other mounts"] = "Outras"
L["All of them"] = "Todas"
L["Kind of source"] = "Tipo de fonte"
L["%d / %d (%d%%)"] = "%d / %d (%d%%)"
L["%d of %d collected (%d%%)"] = "%d de %d coletadas (%d%%)"
L["  ·  showing %d"] = "  ·  mostrando %d"
L["No mount matches the filter."] = "Nenhuma montaria corresponde ao filtro."
L["Click: see it on the card"] = "Clique: ver na ficha"
L["%s on Wowhead.|n|nPress Ctrl+C to copy the link, then paste it in your browser."] =
    "%s no Wowhead.|n|nAperte Ctrl+C para copiar o link e cole no navegador."

-- the minimap tooltip, the same in every Rocket addon (13/10)
L["Click: open the list"] = "Clique: abrir a lista"
L["Right-click: open the options"] = "Clique direito: abrir as opções"

-- the attempts at a mount that drops by chance (13/10)
L["Attempts"] = "Tentativas"
L["Got on attempt %d"] = "Obtida na %dª tentativa"
L["1 attempt so far"] = "1 tentativa até agora"
L["%d attempts so far"] = "%d tentativas até agora"
L["By character: %s"] = "Por personagem: %s"
-- (21/10) the list's Attempts column, over a mount counted and not tried yet
L["None yet"] = "Nenhuma ainda"
L["From the game's statistics of each character, so also from before the addon: %s. A character counts once it logs in with the addon."] =
    "Das estatísticas do jogo de cada personagem, então também de antes do addon: %s. Cada personagem passa a contar quando entra no jogo com o addon."
L["Counted by the addon since it was installed: the game keeps no count of these tries."] =
    "Contadas pelo addon desde que foi instalado: o jogo não guarda a contagem destas tentativas."
-- (16/10) the map button's menu: what the map shows
L["Hide all the markers"] = "Esconder todas as marcações"
L["Only the mounts you are missing"] = "Só as montarias que faltam"
L["The collected ones too"] = "Também as já coletadas"
L["The markers of the mounts are hidden."] = "As marcações das montarias estão escondidas."
L["On the map: the mounts you are missing, and the collected ones with a gold ring."] =
    "No mapa: as montarias que faltam, e as já coletadas com o aro dourado."
L["Click: choose what to show"] = "Clique: escolher o que mostrar"
-- (22/10) the alert before a mount's event (Events.lua). The events' names are the game's own
-- (AreaPOI.ptBR of the client, 12.1): "Grande Escavação" is the head of "Grande Escavação: Descanso do Traidor".
L["Mount events"] = "Eventos de montaria"
L["Event alert"] = "Aviso de evento"
L["A few minutes before an event that leads to a mount you do not have starts: a line in the chat with where it is and a link that points the arrow there, and the alert on the screen if you choose it. Never in combat or inside a dungeon, raid, delve or other instance: it waits, and is dropped if the event starts in the meantime. Quiet once the event's reward of the week is taken."] =
    "Alguns minutos antes de começar um evento que leva a uma montaria que você não tem: uma linha no chat com o lugar e um link que aponta a seta para lá, e o aviso na tela, se você escolher. Nunca em combate nem dentro de masmorra, raide, imersão ou outra instância: o aviso espera, e é descartado se o evento começar nesse meio-tempo. Fica em silêncio depois que a recompensa da semana do evento foi obtida."
L["Event already started"] = "Evento já em andamento"
L["When the alert was held back by combat or an instance and the event started in the meantime: the alert comes once you are free, if the event still has 5 minutes or more to go. Off: only the alert before the start, and one missed in combat or an instance is lost."] =
    "Quando o aviso ficou retido por combate ou instância e o evento começou nesse meio-tempo: o aviso aparece quando você estiver livre, se o evento ainda tiver 5 minutos ou mais pela frente. Desligado: só o aviso antes do começo, e o que você perdeu em combate ou numa instância não volta."
L["Minutes before"] = "Minutos antes"
L["How long before the start the alert comes."] = "Quanto tempo antes do início o aviso chega."
L["The event's reward can bring it."] = "A recompensa do evento pode trazê-la."
L["The event's currency buys it."] = "A moeda do evento a compra."
L["The event's reputation unlocks it."] = "A reputação do evento a libera."
L["Mounts: %s."] = "Montarias: %s."
L["|cffffff00%s|r starts in %s"] = "|cffffff00%s|r começa em %s"
-- (22/10) what the event can give and how often (the user: "mostra o percental de chance e se é diario, semanal, se pode
-- repetir", "e quais montarias podem dar também")
L["can give: %s"] = "pode dar: %s"
L["(you have %d of %d)"] = "(você já tem %d de %d)"
L["%s (you have it)"] = "%s (você já tem)"
L["once a week"] = "1 vez por semana"
L["once a day"] = "1 vez por dia"
L["again at every event"] = "pode repetir a cada evento"
L["%s per %s"] = "%s por %s"
L["%s %s, you have %s"] = "%s %s, você tem %s"
L["renown %d, you are at %d"] = "renome %d, você está no %d"
L["renown %d"] = "renome %d"
L["%s each"] = "%s cada"
L["event alerts %s, %d min before:"] = "avisos de evento %s, %d min antes:"
L["turned off"] = "desligado"
L["you have its mounts"] = "você já tem as montarias"
L["reward taken this week"] = "recompensa da semana já obtida"
L["no known start"] = "sem horário conhecido"
L["will alert"] = "vai avisar"
L["in %s"] = "em %s"
L["the events with a mount, when they start and whether they alert"] = "os eventos com montaria, quando começam e se avisam"
L["Stormarion Assault"] = "Assalto a Tempestrião"
L["Abundance"] = "Abundância"
L["Beledar's Spawn"] = "Cria de Beledar"
L["Nightfall"] = "Ocaso"
L["Time Rift"] = "Fenda Temporal"
L["The Big Dig"] = "Grande Escavação"
L["Community Feast"] = "Banquete da Comunidade"
L["Researchers Under Fire"] = "Pesquisadores sob fogo"
-- (24/10) where, the click, the alert on the screen, and the late alert (Events.lua)
L["|cffffff00%s|r started %s ago, ends in %s"] = "|cffffff00%s|r começou há %s, termina em %s"
L["Starts in %s"] = "Começa em %s"
L["Ends in %s"] = "Termina em %s"
L["point the arrow here"] = "apontar a seta para lá"
L["open the map"] = "abrir o mapa"
L["Click: open the map"] = "Clique: abrir o mapa"
L["Right-click: close"] = "Botão direito: fechar"
L["Can give:"] = "Pode dar:"
L["How to alert"] = "Como avisar"
L["In the chat and on the screen"] = "No chat e na tela"
L["In the chat only"] = "Só no chat"
L["On the screen, the alert is the rare alert's: click it to point the arrow at the event, right-click to close it."] =
    "Na tela, o aviso é o mesmo do aviso de raro: clique nele para apontar a seta para o evento; o botão direito fecha."

-- (22/10) the Attempts tab, the luck of a count, the time spent, today and this week, and the
-- lockouts of each character (AttemptsTab.lua, Attempts.lua, Lockouts.lua)
L["Would have"] = "Já teriam"
L["Today"] = "Hoje"
L["This week"] = "Nesta semana"
L["Time"] = "Tempo"
L["Status"] = "Situação"
L["%d s"] = "%d s"
L["%d min"] = "%d min"
L["%d h %02d min"] = "%d h %02d min"
L["%d d %d h"] = "%d d %d h"
L["With %d attempts at %s, %s of players would already have it. The chance of the next attempt is still %s."] =
    "Com %d tentativas a %s, %s dos jogadores já teriam conseguido. A chance da próxima tentativa continua %s."
L["It came on attempt %d. At %s each, %s of players would have needed fewer attempts."] =
    "Veio na %dª tentativa. A %s por tentativa, %s dos jogadores teriam precisado de menos tentativas."
L["Chance of each attempt: %s"] = "Chance de cada tentativa: %s"
L["Time spent: %s"] = "Tempo gasto: %s"
L["Counted between attempts less than 10 minutes apart, plus each boss fight."] =
    "Conta o intervalo entre tentativas feitas com menos de 10 minutos de diferença, mais cada luta contra chefe."
L["Today: %d · This week: %d"] = "Hoje: %d · Nesta semana: %d"
L["Today: %d"] = "Hoje: %d"
L["Today: %s"] = "Hoje: %s"
L["1 attempt at 1 mount"] = "1 tentativa em 1 montaria"
L["%d attempts at 1 mount"] = "%d tentativas em 1 montaria"
L["%d attempts at %d mounts"] = "%d tentativas em %d montarias"
L["This week: %d at %d"] = "Nesta semana: %d em %d"
L["1 mount with attempts"] = "1 montaria com tentativas"
L["%d mounts with attempts"] = "%d montarias com tentativas"
L["No attempts counted yet. Kill a boss or loot a rare that drops a mount you are missing, and it shows up here."] =
    "Nenhuma tentativa contada ainda. Derrote um chefe ou saqueie um raro que pode dar uma montaria que falta, e ela aparece aqui."
L["Done today"] = "Feito hoje"
L["Done this week"] = "Feito nesta semana"
L["Done"] = "Feito"
L["Partly done"] = "Feito em parte"
L["Available"] = "Disponível"
L["back in %s"] = "volta em %s"
L["%s — back in %s"] = "%s — volta em %s"
L["(the whole warband)"] = "(todo o Bando de Guerra)"
L["%s: the whole warband"] = "%s: todo o Bando de Guerra"
L["Done on %s"] = "Feito em: %s"
L["Still open on %s"] = "Ainda disponível em: %s"
L["Can still go: %s"] = "Ainda disponível para: %s"
L["Characters that never logged in with the addon are not listed."] =
    "Personagens que nunca entraram no jogo com o addon não aparecem."
L["Characters below the maximum level are not offered."] =
    "Personagens abaixo do nível máximo não são sugeridos."
