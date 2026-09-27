-- RocketMount | Locales/ptBR_Tips.lua
-- GERADO por tools/gerar_dicas.py em 2026-09-27 a partir de tools/dicas/*.json -- não edite à mão.
--
-- O português das dicas de jogadores (Data/MountTips.lua), por id de montaria. Fica num
-- arquivo à parte do ptBR.lua porque é gerado, e porque a chave aqui é o id: a frase em
-- inglês como chave dobraria o tamanho de cada dica.
local ADDON, ns = ...

if GetLocale() ~= "ptBR" then return end

ns.MountTipsLocal = {
    [401] = -- Dark Phoenix
        "Vendida pelos vendedores de guilda a personagem Exaltado com uma guilda que tenha {achievement:4988|Glória da Guilda do Aventureiro do Cataclismo}. Entrar numa guilda que já a tem serve, mas a reputação com guilda nova começa do zero. Depois de aprendida, a montaria é sua em qualquer guilda.",
    [802] = -- Long-Forgotten Hippogryph
        "Cinco Cristais Efêmeros aparecem ao mesmo tempo em pontos sorteados de {map:630|Azsuna}, muitos dentro de cavernas. Tocar o primeiro dá 8 horas para tocar os outros quatro; morrer zera a contagem. Outros jogadores estão atrás dos mesmos cristais, e quando alguém termina todos somem até a rodada seguinte.",
    [1617] = -- Verdant Skitterfly
        "Chegue a Renome 25 com {faction:2507|Expedição Dragoscama}. Daí em diante ela tem uma chance pequena de vir em cada Mochila do Batedor da Expedição.",
    [1656] = -- Otto
        "Uma cadeia, quase toda de pesca.\n1. Consiga uma {item:199340|Moeda de Ouro das Ilhas}: pescada nas Ilhas do Dragão, ou 75 {item:199338|Moeda de Cobre das Ilhas} trocadas com {npc:191608|O Grande Zapo}.\n2. Compre dele, com ela, o {item:202102|Saco de Tesouros do Zapo Imaculado}. Quase sempre ele traz os {item:202042|Óculos Aquáticos}; quando não traz, é outra moeda.\n3. Com os óculos, dance por 5 minutos na pista do bar debaixo d'água em {map:2022|Costa Desperta}, em 19.6, 36.5.\n4. Pegue o {item:202061|Barril de Peixe Vazio} e encha: 100 {item:202072|Peixe de Banquisa Frígido} (água aberta em volta de Iskaara), 25 {item:202073|Carpa Calamitosa} (lava em volta da Cidadela Obsidiana) e 1 {item:202074|Reibatana, o Sábio Peixe-de-bigode} (água em volta da Academia Algeth'ar).\n5. Leve o barril de volta para onde você dançou: Otto oferece {quest:72738|O caminho para o coração de um Otto}.",
    [1671] = -- Duskwing Ohuna
        "{item:207026|Coalescência do Surto Onírico} vem dos orbes verdes espalhados pela zona em que o Surto Onírico está ativo, e das criaturas mortas ali. {npc:210608|Celestine da Colheita} fica no símbolo do Surto Onírico no mapa.",
    [2615] = -- Rootstalker Grimlynx, Vibrant Petalwing (Harandar rares)
        "Qualquer raro de {map:2413|Harandar} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens, inclusive de nível 80. Os relatos vão da primeira morte a mais de 2.000.",
    [2708] = -- Rootstalker Grimlynx, Vibrant Petalwing (Harandar rares)
        "Qualquer raro de {map:2413|Harandar} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens, inclusive de nível 80. Os relatos vão da primeira morte a mais de 2.000.",
    [2747] = -- Untainted Grove Crawler
        "Em {map:2413|Harandar}: toque na Marreta Fúngica em 41.3, 67.9, que dá um efeito de 5 minutos, e com o efeito ativo toque o Gongo de Micélio em 46.6, 67.8. O Baú Gera-esporos aparece ao lado do gongo. Um jogador só viu o gongo depois de matar as criaturas em volta; outro clicou no baú, não recebeu nada, e a montaria chegou pelo correio horas depois.",
    [2749] = -- Echo of Aln'sharan
        "1. Faça a cadeia curta de {npc:245637|Su'meera} que começa em {quest:91063|A Trama Florescente} (65.4, 22.6 em {map:2413|Harandar}) e depois a de {npc:242358|Kuri} (67.8, 24.8), de {quest:90467|Contos do céu} até {quest:90474|A lenda de Aln'sharan}. Basta um personagem da conta.\n2. Daí em diante as criaturas de Harandar deixam cair {item:255826|Estilhaços do Céu Misteriosos}, também em imersões e masmorras; os raros, com muito mais frequência. Junte 500.\n3. Entregue-os a Kuri em 66.2, 25.5 pelo botão de ação extra. Parece que nada acontece, mas você recebe um efeito.\n4. Aln'sharan voa alto sobre a zona e fere quem chega perto. Desmonte no ar junto à cabeça dele e clique nele, com uma queda lenta à mão.\nJogadores perderam o efeito, e os 500 estilhaços com ele, ao entrar em grupo ou em campo de batalha antes do passo 4.",
    [2751] = -- Augmented Stormray, Sanguine Harrower (Voidstorm rares)
        "Qualquer raro de {map:2405|Tempestade do Caos} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens, inclusive de nível 80. Os relatos vão da primeira morte a mais de 2.000.",
    [2758] = -- Cobalt Dragonhawk, Cerulean Hawkstrider (Eversong Woods rares)
        "Qualquer raro de {map:2395|Floresta do Canto Eterno} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens. Os relatos vão da primeira morte a mais de 2.000.",
    [2760] = -- Amani Sharptalon, Witherbark Pango (Zul'Aman rares)
        "Qualquer raro de {map:2437|Zul'Aman} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens. Os relatos vão de poucas mortes a mais de 2.000.",
    [2762] = -- Cobalt Dragonhawk, Cerulean Hawkstrider (Eversong Woods rares)
        "Qualquer raro de {map:2395|Floresta do Canto Eterno} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens. Os relatos vão da primeira morte a mais de 2.000.",
    [2764] = -- Duskbrute Harrower
        "{item:267299|Tesouro do Duellum do Matador} é o que {faction:2770|Duellum do Matador} entrega cada vez que a barra de reputação enche de novo depois de a reputação chegar ao máximo. Cerca de 1 tesouro em 4 traz a montaria; os outros podem trazer a mesma mascote repetidas vezes.",
    [2767] = -- Contained Stormarion Defender
        "Dois depósitos podem trazê-la, poucos em cada cem: {item:268485|Depósito Pináculo de Tempestrião Vitorioso}, o semanal por concluir {quest:90962|Assalto a Tempestrião}, e {item:260979|Depósito de Tempestrião Vitorioso}, o da missão mundial do evento. A missão mundial só aparece para o personagem que já concluiu o evento uma vez.",
    [2772] = -- Blessed Amani Burrower
        "O diário diz 1.600 de {currency:3377|Abundância Impoluta}, mas {npc:241928|Chel, a Estilha} cobra 6.400.",
    [2775] = -- Amani Sharptalon, Witherbark Pango (Zul'Aman rares)
        "Qualquer raro de {map:2437|Zul'Aman} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens. Os relatos vão de poucas mortes a mais de 2.000.",
    [2778] = -- Ancestral War Bear
        "O Baú do Guerreiro Honrado fica dentro da base da árvore em 47.0, 82.4 de {map:2437|Zul'Aman}. Clique nele primeiro: só então as quatro Urnas do Guerreiro Honrado respondem. Cada urna chama um guardião que deixa um símbolo: {npc:255171|Escolhido de Nalorakk} em 32.6, 83.5, {npc:255232|Escolhido de Halazzi} em 34.5, 33.4, {npc:255233|Escolhido de Jan'alai} em 54.7, 22.3 e {npc:255231|Escolhido de Akil'zon} em 51.5, 84.9. Com os quatro símbolos, volte ao baú.",
    [2779] = -- Witherbark Warbear Mother
        "Leve 6 de {item:242639|Carne Mais ou Menos Suína} (casa de leilões, ou as feras do lado de fora) para o Sítio Ritualístico {map:2585|Trono Partido}, em Grau 2 ou maior. O Ursinho Perdido fica escondido ao lado de uma árvore em 55.8, 49.5, num patamar a que se chega pulando de cima: dê 1 a ele e ele vira a mascote {item:269836|Gorducho}. Evoque Gorducho junto à Carne Mastigada em 56.0, 38.5 e vem uma ursa de guerra raivosa. Vença-a; ela fica amistosa, e você dá a ela as outras 5.",
    [2786] = -- Hexed Vilefeather Eagle
        "A Caveira de Ritual Abandonada fica numa caverna pequena de {map:2437|Zul'Aman}, em 44.7, 44.1 (entrada em 44.2, 43.5), e pede 1.000 de {item:259361|Essência Torpe}, deixada pelas criaturas da área de elites em volta de 45.8, 40.2. Os jogadores contam de 6 a 7 horas.\nO que torna isso suportável: pegue ali {quest:91838|Vileza enfraquecida}, {quest:91836|Respeite o totem} e {quest:91835|Mandando para casa} e NÃO as entregue. Enquanto elas estão no registro você mantém um botão de ação extra cujo efeito acumula 10 vezes, e cada {npc:248775|Guardião Selvagem} morto acumula um segundo; com os dois, jogadores fizeram sozinhos. Desligue addon que entrega missão por conta própria. Quem já fez essas missões faz em outro personagem.",
    [2790] = -- Insatiable Shredclaw
        "A caverna fica no sul de {map:2405|Tempestade do Caos}, com entrada em 48.9, 78.4. Dentro, ovos quebrados formam um labirinto de círculos de raios; ser atingido devolve você à entrada. A Garra Final de Predaxas está no fim. Jogadores dizem que o círculo para de ferir um pouco antes de sumir, e que um rastro de vento no chão mostra o caminho.",
    [2827] = -- Augmented Stormray, Sanguine Harrower (Voidstorm rares)
        "Qualquer raro de {map:2405|Tempestade do Caos} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens, inclusive de nível 80. Os relatos vão da primeira morte a mais de 2.000.",
    [2829] = -- Lab-Grown Stormray
        "{achievement:62385|De olho no caos} pede 7 de {currency:3400|Amostra do Caos Imaculada}: 1 no começo, depois a cada semana 1 da missão semanal de {npc:248328|Pesquisador do Caos Anomandra}, ao lado do console, e 1 do depósito semanal de {quest:90962|Assalto a Tempestrião}. Cerca de 3 semanas. Se a montaria não vier com a conquista, olhe o correio, ou use Asas do Caos no grimório: a magia põe o item na sua bolsa, onde quer que você esteja.",
    [2839] = -- Delver's Arcane Golem
        "Dentro da imersão Ilha Dendronor, em qualquer Grau: o Baú Resistente em 60.4, 68.1. A imersão tem três Baús Resistentes; a montaria veio deste.",
    [2913] = -- Vivid Chloroceros
        "{currency:3385|Poeira Luminosa} vem das Mariposas Brilhantes espalhadas por {map:2413|Harandar}, 120 ao todo. Parte delas só aparece à medida que o seu Renome com {faction:2704|Hara'ti} sobe: o jogador que as mapeou aconselha chegar ao Renome 9 antes de sair à procura.",
    [2950] = -- Luminous Sporeglider
        "Ela é feita combinando 4 de {item:269245|Lanchesporo Delicioso}. {npc:254176|Necrocharco} dá um por semana, em qualquer dificuldade: quatro semanas no mínimo.",
    [2961] = -- Void-Corrupted Hex Eagle
        "No Sítio Ritualístico {map:2585|Trono Partido}, em Grau 2 ou maior. Uma das quatro caveiras em volta do círculo de ritual em 50.6, 47.3 está sem vela: pegue a Vela Ritualística Fora do Lugar debaixo da árvore em 51.5, 47.8 e coloque-a na caveira a nordeste do círculo. Depois clique nas velas do meio e mate a águia que vem: ela deixa cair a montaria. Se vierem três filhotes de águia, a vela não estava no lugar.",
    [2964] = -- Void-Touched Snapdragon
        "No Sítio Ritualístico {map:2594|Ponto de Espinhadaga}, em qualquer Grau, aparecem até 2 Algas Trazidas pela Água por entrada, entre 8 pontos ao longo das praias. Clicar numa chama criaturas e, com uma chance pequena, o Dracolisco Tocado pelo Caos, que deixa cair a montaria. Os jogadores conferem as algas, saem da instância e entram de novo, sem fazer o ritual. Os relatos falam de 25 a 30 tentativas.",
    [2965] = -- Void-Corrupted Lynx
        "Jogadores a conseguiram nos Graus 1, 2 e 5 dos Sítios Ritualísticos: o Grau não parece decidir. Um deles contou cerca de 20 entradas.",
    [2980] = -- Spirit of Tok'jara
        "No Renome 10 com {faction:2772|Forças de Zul'jarra}, {npc:264611|Du'gal} (50.5, 63.9 em {map:2509|Câmaras de Atal'Utek}) começa uma cadeia de 6 missões, uma por dia, de {quest:96267|Gemas ancestrais} até {quest:96305|A essência inocente}, que dá a montaria. Seis dias no mínimo, e a cadeia é do personagem que a começou.",
    [3005] = -- Lindormi's six mounts (Timelost Saddle)
        "Na 1ª temporada de Midnight, a {item:275436|Sela Perdida no Tempo} veio com {achievement:63097|Mito da Pedra-chave de Midnight: Série 1}, 3.400 de pontuação de Mítica+, e expirou quando a temporada acabou. Cada sela comprava uma das montarias que {npc:197711|Lindormi} vende, à escolha do jogador.",
    [3006] = -- Lindormi's six mounts (Timelost Saddle)
        "Na 1ª temporada de Midnight, a {item:275436|Sela Perdida no Tempo} veio com {achievement:63097|Mito da Pedra-chave de Midnight: Série 1}, 3.400 de pontuação de Mítica+, e expirou quando a temporada acabou. Cada sela comprava uma das montarias que {npc:197711|Lindormi} vende, à escolha do jogador.",
    [3007] = -- Lindormi's six mounts (Timelost Saddle)
        "Na 1ª temporada de Midnight, a {item:275436|Sela Perdida no Tempo} veio com {achievement:63097|Mito da Pedra-chave de Midnight: Série 1}, 3.400 de pontuação de Mítica+, e expirou quando a temporada acabou. Cada sela comprava uma das montarias que {npc:197711|Lindormi} vende, à escolha do jogador.",
    [3008] = -- Lindormi's six mounts (Timelost Saddle)
        "Na 1ª temporada de Midnight, a {item:275436|Sela Perdida no Tempo} veio com {achievement:63097|Mito da Pedra-chave de Midnight: Série 1}, 3.400 de pontuação de Mítica+, e expirou quando a temporada acabou. Cada sela comprava uma das montarias que {npc:197711|Lindormi} vende, à escolha do jogador.",
    [3009] = -- Lindormi's six mounts (Timelost Saddle)
        "Na 1ª temporada de Midnight, a {item:275436|Sela Perdida no Tempo} veio com {achievement:63097|Mito da Pedra-chave de Midnight: Série 1}, 3.400 de pontuação de Mítica+, e expirou quando a temporada acabou. Cada sela comprava uma das montarias que {npc:197711|Lindormi} vende, à escolha do jogador.",
    [3010] = -- Lindormi's six mounts (Timelost Saddle)
        "Na 1ª temporada de Midnight, a {item:275436|Sela Perdida no Tempo} veio com {achievement:63097|Mito da Pedra-chave de Midnight: Série 1}, 3.400 de pontuação de Mítica+, e expirou quando a temporada acabou. Cada sela comprava uma das montarias que {npc:197711|Lindormi} vende, à escolha do jogador.",
    [3031] = -- Hexflame Reaver
        "{npc:258928|Ral'kala} é chamado queimando {item:274422|Relíquia Ossificada} num {npc:265151|Braseiro Assombrado} de {map:2512|A Ilha Enrolada}, 100 para cada chamada, com o modo Pesadelo das caçadas ligado. Para ter saque é preciso ter posto pelo menos 1 relíquia você mesmo e ter acertado nele: o efeito Sussurros do Outro Lado mostra que a sua relíquia contou. Ele não tem limite diário, por isso os grupos o chamam de novo e de novo. A caçada diária no norte da ilha dá 100 relíquias. Enquanto espera, não mate as criaturas em volta do braseiro: isso traz cobras sobre o grupo inteiro.",
    [3036] = -- Sun Festival's Painted Roc
        "Ela vem na {item:117394|Algibeira de Itens Gelados}, entregue pelo primeiro {npc:25740|Ahune} do dia. Só a primeira algibeira do dia da conta inteira pode trazer a montaria. Desde um ajuste de junho de 2026 essa chance dobrou, e ela cresce a cada dia até a montaria vir.",
    [3043] = -- Corroded Soul Crusher
        "O item só diz que a Jornada do Imersor a desbloqueia. Jogadores relatam o grau 5 da Jornada da 2ª temporada.",
    [3051] = -- Topaz Skyfang, Ruby Writhe (Coiled Isle rares)
        "Qualquer raro de {map:2512|A Ilha Enrolada} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens. Os relatos vão da primeira morte a mais de 1.200.",
    [3061] = -- Topaz Skyfang, Ruby Writhe (Coiled Isle rares)
        "Qualquer raro de {map:2512|A Ilha Enrolada} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens. Os relatos vão da primeira morte a mais de 1.200.",
}
