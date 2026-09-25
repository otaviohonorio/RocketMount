-- RocketMount | Locales/ptBR.lua
-- Sobrescreve o que o enUS.lua deixou. Uma chave ausente aqui NÃO é um buraco: ela cai no
-- rótulo do jogo (quando `FROM_GAME` cobre) ou na própria chave, que já é o texto em inglês.
--
-- Regra do projeto para este arquivo: português correto, sem gíria. Jargão do próprio jogo
-- fica (renome, exaltado, raro) porque é o vocabulário que o jogador já usa.
local ADDON, ns = ...

if GetLocale() ~= "ptBR" then return end

local L = ns.L

--------------------------------------------------------------------------------
-- As faixas da lista
--------------------------------------------------------------------------------
-- O nome da faixa cabe em ~36 letras (`TIER_TITLE_WIDTH` no `Window.lua` reserva 230px a
-- 12pt). Passou disso, atravessa a borda da lista -- e o harness conta LETRAS, não bytes,
-- justamente por causa do acento.
L["Guaranteed — just go get it"]  = "Garantidas — é só ir pegar"
L["Guaranteed — nearly unlocked"] = "Garantidas — quase liberadas"
L["Guaranteed — halfway there"]   = "Garantidas — a meio caminho"
L["Down to luck — good odds"]     = "Na sorte — chance boa"
L["Long road"]                    = "Caminho longo"
L["Not confirmed"] = "Sem confirmação"
L["No estimate"]                  = "Sem estimativa"
L["Cannot be obtained any more"]  = "Não dá mais para conseguir"

L["requirement met and checked"]        = "requisito cumprido e conferido"
L["a little left on the requirement"]   = "falta pouco do requisito"
L["road already walked"]                = "caminho já andado"
L["1% or better"]                       = "1% ou mais"
L["bad odds, or a distant requirement"] = "chance ruim, ou requisito longe"
L["open the vendor to confirm"] = "abra o vendedor para confirmar"

-- A validação antes da lista (Core.lua, Window.lua).
L["Checking every mount for this character…"] = "Conferindo cada montaria para este personagem…"
L["%d of %d items loaded"] = "%d de %d itens carregados"
L["waiting for the collection data"] = "esperando os dados da coleção"
L["no data to estimate from"]           = "sem dado para estimar"
L["left the game"]                      = "saiu do jogo"

--------------------------------------------------------------------------------
-- O número da direita e a frase que explica a posição
--------------------------------------------------------------------------------
L["ready to grab"] = "pode pegar"
L["%.0f%% own it"] = "%.0f%% têm"

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
-- Reputação, missão e conquista
--------------------------------------------------------------------------------
L["account-wide reputation"]  = "reputação da conta"
L["this character only (%s)"] = "só deste personagem (%s)"
L["%s: %s — this character does not have it"] = "%s: %s — este personagem não tem"
L["%s: no reputation with this faction on this character"] =
    "%s: nenhuma reputação com esta facção neste personagem"

-- "renome 25 de 5" NÃO É FRASE: a forma "X de Y" só funciona enquanto X caminha para Y.
-- Cumprido se diz cumprido. (Pergunta do usuário: "eu tenho 25 e precisa de 5?")
L["%s: renown %d reached (you are at %d)"]   = "%s: renome %d alcançado (você está em %d)"
L["%s: renown %d of %d"]                     = "%s: renome %d de %d"
L["%s: %s of %s to the next cache"]          = "%s: %s de %s para o próximo baú"
L["%s: asks for %s, which I cannot measure"] = "%s: exige %s, que eu não sei medir"
L["%s: already %s%s"]      = "%s: já está %s%s"
L["at the standing"]       = "no nível"
L["%s: %s of %s to %s%s"]  = "%s: %s de %s para %s%s"
L["the standing"]          = "o nível"

L["%s  ·  %s missing"]  = "%s  ·  faltam %s"
L["%s  ·  you have it"] = "%s  ·  você tem"
L["item %d"]            = "item %d"

L['Quest "%s": completed']                  = 'Missão "%s": concluída'
L["  —  already done on another character"] = "  —  já feita em outro personagem"
L['Quest "%s": not completed%s%s']          = 'Missão "%s": não concluída%s%s'
L["Achievement completed: %s"]              = "Conquista concluída: %s"
L["%s: %d of %d"]                           = "%s: %d de %d"
L['Achievement "%s": not completed']        = 'Conquista "%s": não concluída'

L["Guild vendor: asks for Exalted with the guild and, in most cases, an achievement OF THE GUILD"] =
    "Vendedor de guilda: exige guilda Exaltada e, na maioria, uma conquista DE GUILDA"

--------------------------------------------------------------------------------
-- Quem tem a reputação (o livro-caixa)
--------------------------------------------------------------------------------
L["%s has it (%s)"]             = "%s tem (%s)"
L["on %s"] = "em %s"
L["%s: %s is already %s — buy it on that character"] = "%s: %s já está %s — compre com esse personagem"
L["%s: %s is at %s of %s to %s — the closest of your characters"] = "%s: %s está em %s de %s para %s — o mais perto entre os seus personagens"
L["%s: %s is %s — the closest of your characters"] = "%s: %s está %s — o mais perto entre os seus personagens"
L["this character is the closest of yours to %d mount(s):"] = "este personagem é o mais perto, entre os seus, de %d montaria(s):"
L["%s has it (%s) and %d more"] = "%s tem (%s) e mais %d"

--------------------------------------------------------------------------------
-- A janela
--------------------------------------------------------------------------------
-- "Todas" e não "Tudo": o rótulo vem do jogo (`ALL`), mas aqui ele concorda com "fontes", que
-- é feminino plural. Esta linha é exatamente a precedência que o enUS.lua descreve -- a nossa
-- escolha ganha da palavra do jogo.
L["All"] = "Todas"

L["Rocket Mount — where to start"] = "Rocket Mount — por onde começar"
L["Sources"] = "Fontes"

-- Diário de desenvolvimento (/rmt log). Só existe fora do pacote.
L["the log only exists in development builds."] = "o diário só existe na versão de desenvolvimento."
L["log cleared."] = "diário apagado."
L["log: every line is also printed in chat."] = "diário: cada linha também aparece no chat."
L["log: chat echo off."] = "diário: fora do chat."
L["alert %s; last lines of the log:"] = "aviso %s; últimas linhas do diário:"
L["OFF"] = "DESLIGADO"
L["on"] = "ligado"
L["the development log"] = "o diário de desenvolvimento"

-- O veredito do próprio vendedor (Sources.lua).
L["the vendor sells it to you (seen %s)"] = "o vendedor vende para você (visto em %s)"
L["the vendor does not sell it to you yet (seen %s)"] = "o vendedor ainda não vende para você (visto em %s)"
-- Formato curto de data para "visto em": dia/mês em português.
L["%m/%d"] = "%d/%m"

-- O mapa-múndi (MapPins.lua).
L["Rare"] = "Raro"
L["Rare elite"] = "Raro de elite"
L["Elite"] = "Elite"
L["%dd"] = "%dd"
L["%dh"] = "%dh"
L["%dmin"] = "%dmin"
L["Already looted — back in %s"] = "Já saqueado — volta em %s"
L["Already looted today"] = "Já saqueado hoje"
L["Click: point the arrow here"] = "Clique: apontar a seta para cá"
L["Can drop:"] = "Pode largar:"

-- As tags da lista (Score.lua). "Drop" fica: é o termo que o jogador usa.
L["Raid"] = "Raide"
L["Dungeon"] = "Masmorra"
L["Renown"] = "Renome"
L["Reputation"] = "Reputação"
L["Shop / promotion"] = "Loja / promoção"

-- A lista com colunas (Window.lua).
L["Mount"] = "Montaria"
L["Type"] = "Tipo"
L["Show"] = "Mostrar"
L["Show all"] = "Mostrar todos"
L["Group by type, then %"] = "Agrupar por tipo, depois %"
L["Group by expansion, then %"] = "Agrupar por expansão, depois %"
L["What the percentage means"] = "O que o percentual quer dizer"
L["It is what the mount depends on, and the list is ordered by it."] = "É aquilo de que a montaria depende, e a lista é ordenada por ele."
L["the chance of each attempt"] = "a chance de cada tentativa"
L["how much of it is done"] = "o quanto já está feito"
L["how far to the standing asked for"] = "o caminho até o nível exigido"
L["how far to the renown level asked for"] = "o caminho até o renome exigido"
L['Achievement "%s": %d%% done'] = 'Conquista "%s": %d%% feita'
L["%s: %d%% done"] = "%s: %d%% feita"
L["\"?\" means it cannot be measured yet: open the vendor, or there is no data."] =
    "\"?\" quer dizer que ainda não dá para medir: abra o vendedor, ou não há dado."
L["Show them on the world map"] = "Mostrar no mapa-múndi"
L["Rares, elites and world bosses that drop a mount you do not have, with the mount and the chance when you hover them. Dimmed once looted today."] = "Raros, elites e chefes do mundo que largam montaria que você não tem, com a montaria e a chance ao passar o mouse. Ficam apagados depois de saqueados."
L["errors are NOT being captured on this client."] = "os erros NÃO estão sendo capturados neste cliente."
L["no error captured (capture: %s)."] = "nenhum erro capturado (captura: %s)."
L["%d error(s) captured, %d occurrence(s):"] = "%d erro(s) capturado(s), %d ocorrência(s):"
L["name, boss, zone, vendor"] = "nome, chefe, zona, vendedor"
L["Set map pin"] = "Marcar no mapa"
L["Pick a mount in the list to see how it is obtained."] =
    "Escolha uma montaria na lista para ver como ela se pega."

L["How to get it"] = "Como pega"
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
    "O requisito acima só LIBERA a tentativa. Cumprido ele, a montaria ainda depende da sorte."

L["Why check"] = "Por que conferir"
L["Guild vendor. These ask for reputation with your guild AND an achievement OF THE GUILD — and the achievement is the part I cannot read, because no installed catalogue says which achievement belongs to which mount. The price shown in the requirements is only part of what it costs."] =
    "Vendedor de guilda. Estas exigem reputação com a sua guilda E uma conquista DA GUILDA — e é "
    .. "a conquista que eu não consigo ler, porque nenhum catálogo instalado diz qual conquista "
    .. "pertence a qual montaria. O preço que aparece nos requisitos é só uma parte do que ela "
    .. "custa."
L["Of what I can read, only the price shows up on this mount — and price is almost never what blocks. There may be an achievement, a guild level or a rating in the way, and those I do not read."] =
    "Do que eu consigo ler, só o preço aparece nesta montaria — e preço quase nunca é o que "
    .. "trava. Pode haver conquista, nível de guilda ou classificação no caminho, e isso eu não "
    .. "leio."
L[" Not even the catalogue knows which vendor this one has."] =
    " Nem o catálogo sabe qual é o vendedor exato desta."

L["Where"]                    = "Onde"
L["How many players own it"]  = "Quantos jogadores têm"
L["%.1f%% of the playerbase"] = "%.1f%% da base"
L["Also shows up at"]         = "Também aparece"
L["Black Market"]             = "Mercado Negro"

L["arrow pointed at %s."] = "seta apontada para %s."
L["the mount"]            = "a montaria"

L["%d mounts missing"]      = "%d montarias faltando"
L["Next in line:"]          = "Próxima da fila:"
L["Click to open · right-click for options"] = "Clique para abrir · botão direito para as opções"
L[" (filtered from %d)"]    = " (filtrado de %d)"
L['nothing found for "%s"'] = 'nada encontrado para "%s"'
L["  |cffcc6666· without MCL, there is no drop chance|r"] =
    "  |cffcc6666· sem o MCL, não há a chance de saque|r"
L["  |cff888888· without MountJournalEnhanced, there is no playerbase share|r"] =
    "  |cff888888· sem o MountJournalEnhanced, não há o percentual da base|r"
L["this client has no new menu; use /rmt sources."] =
    "este cliente não tem o menu novo; use /rmt fontes."

--------------------------------------------------------------------------------
-- O aviso de bicho que larga montaria
--------------------------------------------------------------------------------
L["and %d more"]                    = "e mais %d"
L["this map does not accept pins."] = "este mapa não aceita marcação."

-- ⛑ "marcar onde vi" SAIU (22/09). O link marcava os pés do jogador, e não o raro — o relato
-- veio de Luaprata, com a seta cravada na capital para um raro de outra zona. Agora ele aponta
-- para a coordenada que o catálogo guarda, então o rótulo passou a dizer o que ele faz.
L["point me at this rare"] = "apontar para o raro"
L["the rare"]              = "o raro"
L["|cffffff00%s|r can drop: %s%s"]      = "|cffffff00%s|r pode largar: %s%s"

--------------------------------------------------------------------------------
-- O painel de opções
--------------------------------------------------------------------------------
L["Only what I can get"] = "Só o que posso pegar"
L["A mount from the other faction or another class leaves the list. Uncheck to see the whole collection."] =
    "Montaria de outra facção ou de outra classe sai da lista. Desmarque para ver a coleção "
    .. "inteira."

L["Show the minimap button"] = "Mostrar o botão no minimapa"
L["The button opens the list with a click and the options with a right-click. Its tooltip already shows the next mount in line."] =
    "O botão abre a lista com um clique e as opções com o botão direito. A dica dele já mostra a "
    .. "próxima montaria da fila."

L["Alert on mount rares"] = "Avisar de raro com montaria"
L["A rare, elite or world boss that drops a mount you do not have: the alert shows who it is, the mount and the chance. Open world only, and quiet once you looted it."] =
    "Raro, elite ou chefe do mundo que larga montaria que você não tem: o aviso diz quem é, "
    .. "a montaria e a chance. Só no mundo aberto, e em silêncio depois que você saqueou."

L["Show the ones that left the game"] = "Mostrar as que saíram do jogo"
L["Closed promotions, trading card game mounts and retired achievements. They cannot be obtained any more, so they stay out of the list by default."] =
    "Promoções encerradas, montarias de jogo de cartas e conquistas aposentadas. Elas não podem "
    .. "mais ser conseguidas, então ficam fora da lista por padrão."

--------------------------------------------------------------------------------
-- Os comandos
--------------------------------------------------------------------------------
L["the options panel has not registered yet."] = "o painel de opções ainda não registrou."
L["the list shows every missing mount — the row cap was removed in 0.10.0."] =
    "a lista mostra todas as montarias que faltam — o limite de linhas saiu na 0.10.0."
L["minimap button hidden."] = "botão do minimapa escondido."
L["minimap button shown."]  = "botão do minimapa à mostra."

L["expansion: all."] = "expansão: todas."
L["expansion: %s"]   = "expansão: %s"
L["expansion not recognized. These exist:"] = "expansão não reconhecida. As que existem:"

L["search cleared."]     = "busca limpa."
L['searching for "%s".'] = 'buscando por "%s".'

L["mount sighting alert on."]  = "aviso de bicho que larga montaria ligado."
L["mount sighting alert off."] = "aviso de bicho que larga montaria desligado."

L["also showing the ones that left the game."] = "mostrando também as que saíram do jogo."
L["hiding the ones that left the game."]       = "escondendo as que saíram do jogo."

L["only what this character can get"] = "só o que este personagem pode"
L["all"]         = "todas"
L["faction: %s"] = "facção: %s"

L["%d character(s) recorded. The ledger is written as each one logs in — log in with your alts once so they show up here."] =
    "%d personagem(ns) anotado(s). O livro-caixa se escreve quando cada um entra no jogo — entre "
    .. "com os alts uma vez para eles aparecerem aqui."
L["    %s%s  —  %d reputation(s) recorded"] = "    %s%s  —  %d reputações anotadas"

L["source filter cleared: every source is back."] =
    "filtro de fonte limpo: todas as fontes voltam a aparecer."

L['no missing mount has "%s" in its name.'] = 'nenhuma montaria que falta tem "%s" no nome.'
L["MCL (drop chance, coordinates):"] = "MCL (chance de saque, coordenada):"
L["MountJournalEnhanced (share of the playerbase):"] = "MountJournalEnhanced (percentual da base):"
L["|cff33ff99read|r"]    = "|cff33ff99lido|r"
L["|cffff5555missing|r"] = "|cffff5555ausente|r"
L["%d mounts missing on this character:"] = "%d montarias faltando neste personagem:"

L["locale %s, %d game label(s):"]          = "idioma %s, %d rótulo(s) do jogo:"
L["%d game label(s) are not usable here."] = "%d rótulo(s) do jogo não servem aqui."

L["commands:"] = "comandos:"
L["opens and closes the list"]                  = "abre e fecha a lista"
L["clears the source filter"]                   = "limpa o filtro de fonte"
L["filters by faction"]                         = "filtra por facção"
L["shows or hides the ones that left the game"] = "mostra ou esconde as que saíram do jogo"
L["turns the mount sighting alert on or off"]   = "liga e desliga o aviso de bicho que larga montaria"
L["searches by name, boss, zone or vendor"]     = "procura por nome, chefe, zona ou vendedor"
L["filters by expansion"]                       = "filtra por expansão"
L["the characters recorded and how many reputations each one has"] =
    "os personagens anotados e quantas reputações cada um tem"
L["shows or hides the minimap button"]     = "mostra ou esconde o botão do minimapa"
L["options"]                               = "opções"
L["checks the labels taken from the game"] = "confere os rótulos que vêm do jogo"
L["what the addon managed to read"]        = "o que o addon conseguiu ler"
L["everything it knows about one mount"]   = "tudo que ele sabe de uma montaria"
