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
    [682] = -- Voidtalon of the Dark Star
        "A montaria está num ovo do outro lado do Gume da Realidade, um portal, e o ovo sempre a entrega. O portal aparece raramente, em um dos lugares marcados de seis zonas de Draenor, fica alguns minutos e leva só o primeiro jogador que clicar nele. Cada zona conta o tempo por conta própria: os jogadores deixam um personagem em cada zona e percorrem os lugares.",
    [802] = -- Long-Forgotten Hippogryph
        "Cinco Cristais Efêmeros aparecem ao mesmo tempo em pontos sorteados de {map:630|Azsuna}, muitos dentro de cavernas. Tocar o primeiro dá 8 horas para tocar os outros quatro; morrer zera a contagem. Outros jogadores estão atrás dos mesmos cristais, e quando alguém termina todos somem até a rodada seguinte.",
    [1617] = -- Verdant Skitterfly
        "Chegue a Renome 25 com {faction:2507|Expedição Dragoscama}. Daí em diante ela tem uma chance pequena de vir em cada Mochila do Batedor da Expedição.",
    [1656] = -- Otto
        "Uma cadeia, quase toda de pesca.\n1. Consiga uma {item:199340|Moeda de Ouro das Ilhas}: pescada nas Ilhas do Dragão, ou 75 {item:199338|Moeda de Cobre das Ilhas} trocadas com {npc:191608|O Grande Zapo}.\n2. Compre dele, com ela, o {item:202102|Saco de Tesouros do Zapo Imaculado}. Quase sempre ele traz os {item:202042|Óculos Aquáticos}; quando não traz, é outra moeda.\n3. Com os óculos, dance por 5 minutos na pista do bar debaixo d'água em {map:2022|Costa Desperta}, em 19.6, 36.5.\n4. Pegue o {item:202061|Barril de Peixe Vazio} e encha: 100 {item:202072|Peixe de Banquisa Frígido} (água aberta em volta de Iskaara), 25 {item:202073|Carpa Calamitosa} (lava em volta da Cidadela Obsidiana) e 1 {item:202074|Reibatana, o Sábio Peixe-de-bigode} (água em volta da Academia Algeth'ar).\n5. Leve o barril de volta para onde você dançou: Otto oferece {quest:72738|O caminho para o coração de um Otto}.",
    [1671] = -- Duskwing Ohuna
        "{item:207026|Coalescência do Surto Onírico} vem dos orbes verdes espalhados pela zona em que o Surto Onírico está ativo, e das criaturas mortas ali. {npc:210608|Celestine da Colheita} fica no símbolo do Surto Onírico no mapa.",
    [2119] = -- Stonevault Mechsuit
        "{npc:219440|Grão-mensageiro Eirich}, na Abóboda de Pedra em Mítica, pode deixar cair {item:226683|Traje de Meca Defeituoso}, que começa uma cadeia com {npc:213875|Mensageiro Jurlax} (47.0, 32.4 em {map:2214|Fosso Ressonante}). Ele pede três berloques, um de cada vez: {item:219301|Lança-engrenangue Turbinado} de {npc:213216|Mensageira Dorlita} na Abóboda de Pedra, {item:219299|Fermentalizador Sinergético} de {npc:218523|Doura de Ricalhaz Nababa} na Hidromelaria Cinzagris e {item:219306|Buril do Rei da Vela} de {npc:208745|O Rei da Vela} na Fenda Chamanegra. A cadeia é da conta inteira, e o berloque só cai para classe que o usa (o de Doura é de Intelecto): outro personagem pode saqueá-lo. Qualquer nível de item serve.",
    [2144] = -- Delver's mounts sold by Reno Jackson (Dirigible, Gob-Trotter, Mana-Skimmer, OC91 Chariot)
        "Apesar do que diz o diário, desde Midnight {npc:226250|Reno Jackson}, em Dornogal, a vende por 10.000 de {currency:2815|Cristais de Ressonância}.",
    [2159] = -- Machine Defense Unit 1-11
        "O evento de {npc:227273|Maquinista Desperto} em {map:2214|Fosso Ressonante} tem 20 ondas, e a montaria só vem no Baú Desperto que aparece depois da última. Cerca de 6 baús em 100 a trazem; os relatos vão de 10 a mais de 70 tentativas.",
    [2161] = -- Vivid Chloroceros, Elder Glowmite (Luminous Dust)
        "{currency:3385|Poeira Luminosa} vem das Mariposas Brilhantes espalhadas por {map:2413|Harandar}, 120 ao todo. Parte delas só aparece à medida que o seu Renome com {faction:2704|Hara'ti} sobe: o jogador que as mapeou aconselha chegar ao Renome 9 antes de sair à procura.",
    [2165] = -- Soaring Meaderbee
        "{npc:226205|Cendvin} (74.4, 45.2 em {map:2248|Ilha de Dorn}) pede 900 de {item:225557|Pólen Borralheiro Fervilhante}. Ele cai das criaturas de elite a oeste da Hidromelaria Cinzagris: as abelhas e, na costa em volta de 73, 33, {npc:222797|Lobo da Tempestade} e {npc:222796|Ferrinuvem Nanico}. O pólen passa entre os personagens da conta. Os jogadores contam de 3 a 4 horas.",
    [2176] = -- Alunira
        "Alunira voa em volta do pico mais alto de {map:2248|Ilha de Dorn} (23.2, 58.5) atrás de um escudo. Qualquer criatura da ilha tem uma chance pequena de deixar cair {item:224025|Fragmento Estalante}; 10 deles formam um {item:224026|Receptáculo de Tempestade}, que quebra o escudo. Os raros menores, que voltam em minutos, deixam cair fragmentos com muito mais frequência do que as criaturas comuns, e os fragmentos passam entre os personagens da conta.\nEla dá saque uma vez por dia. Não a mate no grupo de outra pessoa no dia em que for usar o seu receptáculo: jogadores perderam o receptáculo assim.",
    [2178] = -- Nesting Swarmite
        "Nas Visões Horrendas, cada distrito tem uma pilha de lixo; clicar nela chama criaturas e, de vez em quando, o Enxamito Aninhado, que sempre deixa cair a montaria. Não é preciso máscara. Os jogadores conferem uma ou duas pilhas, saem da visão e entram de novo; os relatos vão da primeira pilha a mais de 70 tentativas.\n{map:2404|Visão de Ventobravo}: 55.8, 49.3 · 62.9, 30.7 · 73.6, 62.7 · 66.1, 76.3 · 52.6, 77.3.\n{map:2403|Visão de Orgrimmar}: 47.8, 75.0 · 40.7, 79.3 · 50.9, 45.2 · 69.0, 49.8 · 57.5, 60.6, esta dentro de uma loja e menor.",
    [2192] = -- Beledar's Spawn
        "{npc:207802|Cria de Beledar} aparece em {map:2215|Pouso Santo} quando Beledar escurece, a cada 3 horas, em um de vários pontos. Dá saque uma vez por dia por personagem, e cerca de 1 morte em 18 dá a montaria. Ela morre em segundos: os jogadores entram num grupo que tenha todos os pontos cobertos.",
    [2194] = -- Dauntless Imperial Lynx
        "Ela vem na {item:228741|Algibeira de Suprimentos dos Luminares}, entregue pelas fogueiras de {quest:76586|Semeando a Luz} em {map:2215|Pouso Santo}: as principais, e as missões paralelas que as fogueiras pequenas dão por 3 cristais. Menos de 1 algibeira em 100 a traz, e os relatos passam de 300. Personagem de nível 70 pode fazer.",
    [2205] = -- Ol' Mole Rufus
        "Cinco alavancas espalhadas por {map:2214|Fosso Ressonante} têm de ser puxadas ao mesmo tempo, por isso são precisos cinco jogadores. Uma mensagem no chat diz que deu certo, e algum tempo depois {npc:220285|Tocaieiro das Profundezas} aparece. Saque uma vez por dia por personagem, também abaixo do nível 80. O Wowhead conta cerca de 1 montaria em 17 mortes; jogadores que contaram em raides dizem menos.",
    [2222] = -- Siesbarg
        "{npc:216046|Tka'ktath} (63, 66 em {map:2255|Azj-Kahet}, no alto de uma plataforma) deixa cair {item:225952|Ampola de Sangue de Tka'ktath} para personagem de nível 78 ou mais. Ele leva horas para voltar e é difícil sozinho; o saque é uma vez por dia. A ampola começa uma cadeia que pede, nesta ordem, 1.500 de {item:225950|Quitina Nerubiana}, 1.000 de {item:226135|Veneno Nerubiano} e 500 de {item:226136|Sangue Nerubiano}, todos de criaturas nerubianas, o sangue de poucas delas. A cadeia é do personagem. Os jogadores repetem as primeiras salas das masmorras Ara-Kara e Cidade das Tramas com seguidores, saindo e entrando de novo.",
    [2225] = -- Timewalking vendor mounts
        "O vendedor só está lá enquanto a Caminhada Temporal da expansão dele está ativa. {currency:1166|Insígnia Transtemporal} pode ser passada entre os personagens da conta, na aba de moedas.",
    [2274] = -- Undermine cartel troves (Blackwater, Steamwheedle, Venture Co., Bilgewater)
        "A arca é o que o cartel entrega cada vez que a barra de reputação enche de novo depois de Exaltado. Cerca de 1 arca em 4 traz a montaria: muitos jogadores a conseguiram na primeira, um precisou de 16.",
    [2276] = -- Ando the Gat's mounts (Darkfuse Chompactor, Flarendo the Furious, Thunderdrum Misfire)
        "{npc:235621|Ando, o Cato} fica DENTRO da raide Libertação da Inframina, subindo a escada depois da entrada. Os jogadores chegam a ele pelo Localizador de Raides, que {npc:231045|Teco Fineza} abre em 43.4, 51.5 de {map:2346|Inframina}.",
    [2278] = -- Ando the Gat's mounts (Darkfuse Chompactor, Flarendo the Furious, Thunderdrum Misfire)
        "{npc:235621|Ando, o Cato} fica DENTRO da raide Libertação da Inframina, subindo a escada depois da entrada. Os jogadores chegam a ele pelo Localizador de Raides, que {npc:231045|Teco Fineza} abre em 43.4, 51.5 de {map:2346|Inframina}.",
    [2279] = -- Ando the Gat's mounts (Darkfuse Chompactor, Flarendo the Furious, Thunderdrum Misfire)
        "{npc:235621|Ando, o Cato} fica DENTRO da raide Libertação da Inframina, subindo a escada depois da entrada. Os jogadores chegam a ele pelo Localizador de Raides, que {npc:231045|Teco Fineza} abre em 43.4, 51.5 de {map:2346|Inframina}.",
    [2281] = -- Undermine cartel troves (Blackwater, Steamwheedle, Venture Co., Bilgewater)
        "A arca é o que o cartel entrega cada vez que a barra de reputação enche de novo depois de Exaltado. Cerca de 1 arca em 4 traz a montaria: muitos jogadores a conseguiram na primeira, um precisou de 16.",
    [2283] = -- Miscellaneous Mechanica mounts (Innovation Investigator, Asset Advocator, Margin Manipulator)
        "{item:234741|Mecanismos Diversos} cai, raramente, dos raros que cada cartel chama em {map:2346|Inframina}, e não só na primeira morte do dia; jogadores também o acharam nas caçambas transbordando. {npc:228286|Marquita Franjínea} fica em 43.3, 82.8. Os jogadores a consideram uma das coletas mais longas da expansão: um deles comprou a terceira montaria na casa de leilões.",
    [2289] = -- Undermine cartel troves (Blackwater, Steamwheedle, Venture Co., Bilgewater)
        "A arca é o que o cartel entrega cada vez que a barra de reputação enche de novo depois de Exaltado. Cerca de 1 arca em 4 traz a montaria: muitos jogadores a conseguiram na primeira, um precisou de 16.",
    [2290] = -- Miscellaneous Mechanica mounts (Innovation Investigator, Asset Advocator, Margin Manipulator)
        "{item:234741|Mecanismos Diversos} cai, raramente, dos raros que cada cartel chama em {map:2346|Inframina}, e não só na primeira morte do dia; jogadores também o acharam nas caçambas transbordando. {npc:228286|Marquita Franjínea} fica em 43.3, 82.8. Os jogadores a consideram uma das coletas mais longas da expansão: um deles comprou a terceira montaria na casa de leilões.",
    [2291] = -- Salvaged Goblin Gazillionaire's Flying Machine
        "{npc:234621|Entulho do Gallagio} pode aparecer quando a barra de lixo recolhido de um evento de S.U.C.A.T.A. chega a 500, e não quando o evento termina. São precisos 3 jogadores ou mais para encher a barra. O mesmo personagem pode matá-lo várias vezes no mesmo dia; cerca de 1 morte em 60 dá a montaria.",
    [2292] = -- Miscellaneous Mechanica mounts (Innovation Investigator, Asset Advocator, Margin Manipulator)
        "{item:234741|Mecanismos Diversos} cai, raramente, dos raros que cada cartel chama em {map:2346|Inframina}, e não só na primeira morte do dia; jogadores também o acharam nas caçambas transbordando. {npc:228286|Marquita Franjínea} fica em 43.3, 82.8. Os jogadores a consideram uma das coletas mais longas da expansão: um deles comprou a terceira montaria na casa de leilões.",
    [2293] = -- Darkfuse Spy-Eye
        "{npc:231310|Precipitante de Sombrafuso} é chamado com {item:229823|Recipiente de Solução Sombrafuso}, que {npc:231396|Chico Papossério} vende a quem tem Renome 6 com {faction:2653|Cartéis da Inframina} e é Amistoso com {faction:2669|Soluções Sombrafuso}; ele vai no pilar em 40.6, 91.8 de {map:2346|Inframina}. Quem estiver ali pode saquear, uma vez por semana por personagem. Cerca de 1 morte em 23 dá a montaria.",
    [2295] = -- Undermine cartel troves (Blackwater, Steamwheedle, Venture Co., Bilgewater)
        "A arca é o que o cartel entrega cada vez que a barra de reputação enche de novo depois de Exaltado. Cerca de 1 arca em 4 traz a montaria: muitos jogadores a conseguiram na primeira, um precisou de 16.",
    [2296] = -- Delver's mounts sold by Reno Jackson (Dirigible, Gob-Trotter, Mana-Skimmer, OC91 Chariot)
        "Apesar do que diz o diário, desde Midnight {npc:226250|Reno Jackson}, em Dornogal, a vende por 10.000 de {currency:2815|Cristais de Ressonância}.",
    [2303] = -- Violet Goblin Shredder
        "Ela vem com a recompensa de uma sequência de serviços de Fretes e Remessas em {map:2346|Inframina}, para quem tem Renome 8 com {faction:2653|Cartéis da Inframina}. Jogadores a conseguiram também fora do surto, e sem ser na primeira sequência do dia.",
    [2317] = -- Timewalking vendor mounts
        "O vendedor só está lá enquanto a Caminhada Temporal da expansão dele está ativa. {currency:1166|Insígnia Transtemporal} pode ser passada entre os personagens da conta, na aba de moedas.",
    [2322] = -- Thrayir, Eyes of the Siren
        "Thrayir está na Cripta Esquecida de {map:2369|Ilha das Sirenas} (caverna em 44.0, 23.1) entre 5 pedras rúnicas, cada uma pedindo uma chave rúnica. As chaves só são achadas e usadas na tempestade: {npc:227815|Suzi Fresaprego} (69.0, 49.1) leva você para ela depois de feita a {quest:84850|Ira da serpente} da semana.\n- {item:232571|Chave Rúnica Rodopiante}: {npc:231368|Ksvir, o Esquecido}, na cripta.\n- {item:232569|Chave Rúnica Ciclônica}: {npc:231357|Zek'ul Quebra-barco}, ou pescada onde ele aparece.\n- {item:232572|Chave Rúnica Torrencial}: 7 de {item:234328|Fragmento Torrencial}, de qualquer criatura na tempestade.\n- {item:232573|Chave Rúnica Trovejante}: 5 de {item:232605|Fragmento Trovejante}, de baús.\n- {item:232570|Chave Rúnica Turbulenta}: 3 de {item:234327|Fragmento Turbulento}, em 38.2, 51.8 · 67.1, 78.4 · 52.4, 38.6.",
    [2334] = -- Bronze Goblin Waveshredder
        "{item:232465|Arca de Sombrafuso} é o que {faction:2669|Soluções Sombrafuso} entrega cada vez que a barra de reputação enche de novo depois de Exaltado. Cerca de 1 arca em 5 traz a montaria.",
    [2470] = -- Timewalking vendor mounts
        "O vendedor só está lá enquanto a Caminhada Temporal da expansão dele está ativa. {currency:1166|Insígnia Transtemporal} pode ser passada entre os personagens da conta, na aba de moedas.",
    [2471] = -- Timewalking vendor mounts
        "O vendedor só está lá enquanto a Caminhada Temporal da expansão dele está ativa. {currency:1166|Insígnia Transtemporal} pode ser passada entre os personagens da conta, na aba de moedas.",
    [2473] = -- Timewalking vendor mounts
        "O vendedor só está lá enquanto a Caminhada Temporal da expansão dele está ativa. {currency:1166|Insígnia Transtemporal} pode ser passada entre os personagens da conta, na aba de moedas.",
    [2474] = -- Timewalking vendor mounts
        "O vendedor só está lá enquanto a Caminhada Temporal da expansão dele está ativa. {currency:1166|Insígnia Transtemporal} pode ser passada entre os personagens da conta, na aba de moedas.",
    [2496] = -- Void-Scarred Gryphon
        "Em {map:2404|Visão de Ventobravo}, uma das Visões Horrendas, com pelo menos 2 máscaras. Dois bilhetes rasgados no Distrito Comercial dizem o que o grifo come: o de 65.6, 71.6 diz se é cru ou cozido, o de 68.7, 73.3 diz qual comida. Ponha-a na tigela em 67.8, 73.3 e sacuda a tigela: o grifo que pousa deixa cair a montaria. A comida errada traz ratos e custa a tentativa, por isso os jogadores levam as 8. Cruas: {item:222741|Filé Fresco}, {item:222737|Micoflorescência em Pedaços}, {item:222739|Caldo de Carne Temperado}, {item:222738|Bife Porcionado}. Cozidas: {item:222702|Espetinho de Filé}, {item:222705|Micoflorescência Assada}, {item:222703|Ensopadinho}, {item:222704|Bife do Campo Sem Tempero}. Não é preciso concluir o distrito.",
    [2497] = -- Void-Forged Stallion
        "Em {map:2404|Visão de Ventobravo}, uma das Visões Horrendas, com pelo menos 1 máscara, pegue as 4 ferraduras, uma por distrito: 56.1, 55.5 · 75.6, 56.8 · 61.5, 75.6 · 51.0, 84.1. Leve-as à forja em 62.9, 37.1, no Distrito dos Anões: o garanhão que aparece deixa cair a montaria. Saqueie-o, pois ela não vem pelo correio. Só funciona na semana em que a visão é a de Ventobravo.",
    [2498] = -- Void-Scarred Pack Mother
        "Em {map:2403|Visão de Orgrimmar}, uma das Visões Horrendas, com pelo menos 1 máscara: pegue a sela de lobo em 67.4, 36.2 e a bolsa de arreios de lobo em 39.2, 49.6, depois clique no tapete de pele de lobo em 60.9, 55.1, dentro da loja de couraria. O lobo que aparece deixa cair a montaria.",
    [2499] = -- Void-Scarred Windrider
        "Em {map:2403|Visão de Orgrimmar}, uma das Visões Horrendas, com pelo menos 2 máscaras: conclua o Vale da Sabedoria, o que libera o elevador em 49.2, 50.7. Suba e vá para o sul, até onde ficam as mantícoras (48.7, 54.9), e mate as ondas até vir a matriarca: ela deixa cair a montaria.",
    [2502] = -- Void-Crystal Panther
        "Aquilo de que ela é feita só vem das Visões Horrendas, com pelo menos 1 máscara, e não é preciso profissão para juntar. Mate {npc:241024|Grande Keech} uma vez, no Vale da Honra da visão de Orgrimmar: ele dá {item:238924|Orbe do Mistério Atado ao Caos} e, a um joalheiro, a receita. Daí em diante o altar do Vale da Sabedoria dá {item:239107|Barra Infusa de Sangue Negro} e cada baú de recompensa de uma tentativa dá um {item:239106|Ônix Infuso em Sombra}. Os jogadores contam 5 tentativas. Quem não é joalheiro manda fazer por encomenda de criação.",
    [2505] = -- Resplendent K'arroc
        "Não é missão mundial, apesar do que diz o diário: {npc:231820|Ve'nari}, no Oásis de {map:2371|K'aresh}, oferece {quest:88976|A esperança de K'aresh} a quem tem {achievement:41811|Estabilidade ecológica}.",
    [2511] = -- Terror of the Night
        "Os mandados são semanais: a cada semana vem um de 6, sorteado, em 48.7, 57.7 de {map:2472|Tazavesh, o Mercado Oculto}, e cada um é uma cadeia curta que termina com um raro para chamar e matar. Com os 6 feitos vem a montaria: seis semanas no mínimo.",
    [2512] = -- Delver's mounts sold by Reno Jackson (Dirigible, Gob-Trotter, Mana-Skimmer, OC91 Chariot)
        "Apesar do que diz o diário, desde Midnight {npc:226250|Reno Jackson}, em Dornogal, a vende por 10.000 de {currency:2815|Cristais de Ressonância}.",
    [2535] = -- Void-Scarred Lynx
        "Ela vem na {item:239546|Bolsa do Sectário Confiscada}, a bolsa das missões DIÁRIAS das incursões em {map:2215|Pouso Santo}, e não na algibeira semanal. Menos de 1 bolsa em 100 a traz; os relatos vão da 3ª bolsa a mais de 500.",
    [2552] = -- Lavender K'arroc, Acidic Void Creeper (Untethered Coin)
        "{quest:91093|Não é só uma fase} dá 7 de {currency:3303|Moeda Desprendida} por semana à conta inteira. {npc:241624|Shad'anis} pede 66 por tudo o que vende.",
    [2557] = -- Lavender K'arroc, Acidic Void Creeper (Untethered Coin)
        "{quest:91093|Não é só uma fase} dá 7 de {currency:3303|Moeda Desprendida} por semana à conta inteira. {npc:241624|Shad'anis} pede 66 por tudo o que vende.",
    [2560] = -- Blue Barry
        "No Renome 9 com {faction:2658|Truste K'areshi}, {npc:238016|Ba'eth} (57.6, 58.1 em {map:2472|Tazavesh, o Mercado Oculto}) começa uma cadeia que anda um passo por dia, de {quest:90663|Roubar o que é nosso} até {quest:90769|Tudo azul}, que dá a montaria. Quatro dias no mínimo, e um dia sem fazer é um dia a mais.",
    [2561] = -- Curious Slateback
        "{item:245611|Depósito Pináculo Estrebuchante} vem uma vez por semana, e cerca de 3 depósitos em 100 trazem a montaria. Jogadores o abriram toda semana por meses.",
    [2586] = -- Timewalking vendor mounts
        "O vendedor só está lá enquanto a Caminhada Temporal da expansão dele está ativa. {currency:1166|Insígnia Transtemporal} pode ser passada entre os personagens da conta, na aba de moedas.",
    [2587] = -- Timewalking vendor mounts
        "O vendedor só está lá enquanto a Caminhada Temporal da expansão dele está ativa. {currency:1166|Insígnia Transtemporal} pode ser passada entre os personagens da conta, na aba de moedas.",
    [2602] = -- Translocated Gorger
        "Ela é feita de 20 de {item:246240|Cápsula de Energia Devorada}. Cada um dos 4 raros dos ataques de devoradores dá uma por semana à conta: {npc:231229|Korgoth, o Voraz} (71.8, 28.2), {npc:234970|Iramiasma} (50.6, 54.0) e um terceiro em 49.5, 64.2 em {map:2371|K'aresh}, {npc:235104|O Quebramuros} (28.6, 74.3) em {map:2472|Tazavesh, o Mercado Oculto}. São 4 por semana no máximo, portanto 5 semanas. Um ataque acontece de cada vez, e o mapa o mostra; o raro vem quando a barra de devoradores mortos enche.",
    [2603] = -- Sthaarbs's Last Lunch
        "{npc:234845|Sthaarbs} aparece no meio do Oásis de {map:2371|K'aresh} (74.0, 32.5) cerca de uma hora depois de morrer, e só pode ser enfrentado de dentro do Mergulho Fásico: é preciso ter {item:235499|Faixas de Reshii} e nível 80. Ao lado do conduíte em 75.8, 33.0 um botão extra leva você às plataformas em volta dele. Saque uma vez por semana por personagem; cerca de 1 morte em 15 dá a montaria.",
    [2604] = -- Delver's mounts sold by Reno Jackson (Dirigible, Gob-Trotter, Mana-Skimmer, OC91 Chariot)
        "Apesar do que diz o diário, desde Midnight {npc:226250|Reno Jackson}, em Dornogal, a vende por 10.000 de {currency:2815|Cristais de Ressonância}.",
    [2615] = -- Rootstalker Grimlynx, Vibrant Petalwing (Harandar rares)
        "Qualquer raro de {map:2413|Harandar} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens, inclusive de nível 80. Os relatos vão da primeira morte a mais de 2.000.",
    [2655] = -- Phase-Lost Slateback
        "Os orbes de {achievement:61017|Achados e perdidos na fase} só aparecem dentro do Mergulho Fásico, em {map:2371|K'aresh} e em Tazavesh, e pedem {item:235499|Faixas de Reshii} no grau 3. Cerca de 1 orbe em 5 dá uma arma, sempre uma que você ainda não tem. Dois jogadores não pegam o mesmo orbe. Os jogadores fizeram em 30 minutos a algumas horas, dando a volta nas ilhas.",
    [2693] = -- Blessed Amani Burrower, Amani Sunfeather (Abundance vendor)
        "O diário diz 1.600 de {currency:3377|Abundância Impoluta}, mas {npc:241928|Chel, a Estilha} cobra 6.400.",
    [2708] = -- Rootstalker Grimlynx, Vibrant Petalwing (Harandar rares)
        "Qualquer raro de {map:2413|Harandar} pode deixá-la cair, cada um com cerca de 1 chance em 1.000. Um raro dá saque uma vez por dia por personagem, por isso os jogadores repetem a volta em outros personagens, inclusive de nível 80. Os relatos vão da primeira morte a mais de 2.000.",
    [2713] = -- Ruddy Sporeglider
        "O Caldeirão Peculiar (40.7, 28.1 em {map:2413|Harandar}) abre com 150 de {item:260531|Fragmento de Resina Cristalizada}. Eles vêm, de 2 a 7 por vez, da Seiva Endurecida pelo Fogo de Teldrassil caída no rio que corre de 40.0, 21.4 até 49.3, 51.2, e em nenhuma outra água. A seiva volta tão depressa quanto é recolhida. Do alto, sobre o rio, o contorno dela é mais fácil de ver.",
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
    [2772] = -- Blessed Amani Burrower, Amani Sunfeather (Abundance vendor)
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
    [2913] = -- Vivid Chloroceros, Elder Glowmite (Luminous Dust)
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
