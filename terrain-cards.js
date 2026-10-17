(() => {
 'use strict';
 const data={
  "version": "terrain-1",
  "cards": [
    {
      "id": "yggdrasil",
      "name": "Yggdrasil",
      "type": "Terreno",
      "faction": "Nórdicos",
      "symbol": "⌁",
      "power": 0,
      "cost": null,
      "kind": "terrain",
      "glow": "rgba(134,91,178,.42)",
      "badgeKey": "norse",
      "art": "assets/terrains/yggdrasil.png",
      "abilityTitle": "Bônus de Terreno",
      "ability": "Fortalece Odin em +2 de poder.",
      "previewOnly": false,
      "story": [
        "Yggdrasil · Terreno · Facção Nórdicos.",
        "Fortalece Odin em +2 de poder.",
        "O bônus vale para os dois jogadores enquanto este terreno ocupa o espaço compartilhado."
      ],
      "sourceCard": "codex-clipboard-147dfbf7-7293-4fc0-8b70-77a33b195fd4.png"
    },
    {
      "id": "alto-egito",
      "name": "Alto Egito",
      "type": "Terreno",
      "faction": "Egípcios",
      "symbol": "⌁",
      "power": 0,
      "cost": null,
      "kind": "terrain",
      "glow": "rgba(211,165,42,.42)",
      "badgeKey": "egypt",
      "art": "assets/terrains/alto-egito.jpg",
      "abilityTitle": "Bônus de Terreno",
      "ability": "Fortalece todos os egípcios em +2 de poder.",
      "previewOnly": false,
      "story": [
        "Alto Egito · Terreno · Facção Egípcios.",
        "Fortalece todos os egípcios em +2 de poder.",
        "O bônus vale para os dois jogadores enquanto este terreno ocupa o espaço compartilhado."
      ],
      "sourceCard": "codex-clipboard-682c5fec-6295-4ad8-80d9-2745ccf62e8d.jpg"
    },
    {
      "id": "baixo-egito",
      "name": "Baixo Egito",
      "type": "Terreno",
      "faction": "Egípcios",
      "symbol": "⌁",
      "power": 0,
      "cost": null,
      "kind": "terrain",
      "glow": "rgba(211,165,42,.42)",
      "badgeKey": "egypt",
      "art": "assets/terrains/baixo-egito.png",
      "abilityTitle": "Bônus de Terreno",
      "ability": "Fortalece todos os egípcios em +2 de poder.",
      "previewOnly": false,
      "story": [
        "Baixo Egito · Terreno · Facção Egípcios.",
        "Fortalece todos os egípcios em +2 de poder.",
        "O bônus vale para os dois jogadores enquanto este terreno ocupa o espaço compartilhado."
      ],
      "sourceCard": "codex-clipboard-45ad8471-4014-4577-b009-2383bb8098d8.png"
    },
    {
      "id": "bifrost",
      "name": "Bifrost",
      "type": "Terreno",
      "faction": "Nórdicos",
      "symbol": "⌁",
      "power": 0,
      "cost": null,
      "kind": "terrain",
      "glow": "rgba(134,91,178,.42)",
      "badgeKey": "norse",
      "art": "assets/terrains/bifrost.png",
      "abilityTitle": "Bônus de Terreno",
      "ability": "Fortalece todos os nórdicos, exceto Loki, em +2 de poder.",
      "previewOnly": false,
      "story": [
        "Bifrost · Terreno · Facção Nórdicos.",
        "Fortalece todos os nórdicos, exceto Loki, em +2 de poder.",
        "O bônus vale para os dois jogadores enquanto este terreno ocupa o espaço compartilhado."
      ],
      "sourceCard": "codex-clipboard-643abb3d-5fa1-4198-bc38-35d696586674.png"
    },
    {
      "id": "esparta",
      "name": "Esparta",
      "type": "Terreno",
      "faction": "Grécia",
      "symbol": "⌁",
      "power": 0,
      "cost": null,
      "kind": "terrain",
      "glow": "rgba(36,91,137,.42)",
      "badgeKey": "greece",
      "art": "assets/terrains/esparta.png",
      "abilityTitle": "Bônus de Terreno",
      "ability": "Fortalece os espartanos em +2 de poder e Ares em +3 de poder.",
      "previewOnly": false,
      "story": [
        "Esparta · Terreno · Facção Grécia.",
        "Fortalece os espartanos em +2 de poder e Ares em +3 de poder.",
        "O bônus vale para os dois jogadores enquanto este terreno ocupa o espaço compartilhado."
      ],
      "sourceCard": "codex-clipboard-44c87658-0390-4813-b67e-ca0b19864760.png"
    },
    {
      "id": "labirinto-dedalos",
      "name": "Labirinto de Dédalos",
      "type": "Terreno",
      "faction": "Grécia",
      "symbol": "⌁",
      "power": 0,
      "cost": null,
      "kind": "terrain",
      "glow": "rgba(36,91,137,.42)",
      "badgeKey": "greece",
      "art": "assets/terrains/labirinto-dedalos.png",
      "abilityTitle": "Bônus de Terreno",
      "ability": "Fortalece o Minotauro e os monstros gregos em +2 de poder.",
      "previewOnly": false,
      "story": [
        "Labirinto de Dédalos · Terreno · Facção Grécia.",
        "Fortalece o Minotauro e os monstros gregos em +2 de poder.",
        "O bônus vale para os dois jogadores enquanto este terreno ocupa o espaço compartilhado."
      ],
      "sourceCard": "codex-clipboard-0a0b4557-0561-400b-9d7f-d3022d4e15a7.png"
    },
    {
      "id": "campo-troia",
      "name": "Troia",
      "type": "Terreno",
      "faction": "Grécia",
      "symbol": "⌁",
      "power": 0,
      "cost": 2,
      "kind": "terrain",
      "glow": "rgba(36,91,137,.42)",
      "badgeKey": "greece",
      "art": "assets/terrains/campo-troia.png",
      "abilityTitle": "Bônus de Terreno",
      "ability": "Fortalece Aquiles, Athena e Ares em +3 de poder.",
      "previewOnly": false,
      "story": [
        "Troia · Terreno · Facção Grécia.",
        "Fortalece Aquiles, Athena e Ares em +3 de poder.",
        "O bônus vale para os dois jogadores enquanto este terreno ocupa o espaço compartilhado."
      ],
      "sourceCard": "codex-clipboard-2e46e5be-57eb-4ab4-a879-91cfb89897f8.png"
    },
    {
      "id": "nilfheim",
      "name": "Nilfheim",
      "type": "Terreno",
      "faction": "Nórdicos",
      "symbol": "⌁",
      "power": 0,
      "cost": null,
      "kind": "terrain",
      "glow": "rgba(134,91,178,.42)",
      "badgeKey": "norse",
      "art": "assets/terrains/nilfheim.png",
      "abilityTitle": "Bônus de Terreno",
      "ability": "Fortalece Loki e os gigantes de gelo em +2 de poder.",
      "previewOnly": false,
      "story": [
        "Nilfheim · Terreno · Facção Nórdicos.",
        "Fortalece Loki e os gigantes de gelo em +2 de poder.",
        "O bônus vale para os dois jogadores enquanto este terreno ocupa o espaço compartilhado."
      ],
      "sourceCard": "codex-clipboard-722d05ed-a942-4260-8793-ede44b99ff93.png"
    }
  ],
  "rules": {
    "yggdrasil": [
      {
        "ids": [
          "odin"
        ],
        "bonus": 2
      }
    ],
    "alto-egito": [
      {
        "faction": "Egípcios",
        "bonus": 2
      }
    ],
    "baixo-egito": [
      {
        "faction": "Egípcios",
        "bonus": 2
      }
    ],
    "bifrost": [
      {
        "faction": "Nórdicos",
        "excludeIds": [
          "loki"
        ],
        "bonus": 2
      }
    ],
    "esparta": [
      {
        "ids": [
          "ares"
        ],
        "bonus": 3
      },
      {
        "tagsAny": [
          "espartano"
        ],
        "bonus": 2
      }
    ],
    "labirinto-dedalos": [
      {
        "ids": [
          "minotauro"
        ],
        "bonus": 2
      },
      {
        "faction": "Grécia",
        "tagsAny": [
          "monstro"
        ],
        "bonus": 2
      }
    ],
    "campo-troia": [
      {
        "ids": [
          "aquiles",
          "athena",
          "ares"
        ],
        "bonus": 3
      }
    ],
    "nilfheim": [
      {
        "ids": [
          "loki"
        ],
        "bonus": 2
      },
      {
        "tagsAny": [
          "gigante-de-gelo"
        ],
        "bonus": 2
      }
    ]
  },
  "metadata": {
    "soldado-esparta": {
      "name": "Soldado de Esparta",
      "power": 3,
      "faction": "Grécia",
      "tags": [
        "espartano"
      ]
    },
    "athena": {
      "name": "Athena",
      "power": 4,
      "faction": "Grécia",
      "tags": []
    },
    "lobo-alfa": {
      "name": "Lobisomem Alfa",
      "power": 4,
      "faction": "Monstros",
      "tags": [
        "monstro"
      ]
    },
    "guardiao-nordico": {
      "name": "Guardião Nórdico",
      "power": 2,
      "faction": "Nórdicos",
      "tags": []
    },
    "mjolnir": {
      "name": "Mjölnir",
      "power": 0,
      "faction": "Nórdicos",
      "tags": []
    },
    "runas-nordicas": {
      "name": "Runas Nórdicas",
      "power": 0,
      "faction": "Nórdicos",
      "tags": []
    },
    "grecia": {
      "name": "Grécia",
      "power": 0,
      "faction": "Grécia",
      "tags": []
    },
    "eclipse": {
      "name": "Eclipse",
      "power": 0,
      "faction": "Universal",
      "tags": []
    },
    "campo-troia": {
      "name": "Troia",
      "power": 0,
      "faction": "Grécia",
      "tags": []
    },
    "medusa": {
      "name": "Medusa",
      "power": 4,
      "faction": "Grécia",
      "tags": [
        "monstro"
      ]
    },
    "poseidon": {
      "name": "Poseidon",
      "power": 7,
      "faction": "Grécia",
      "tags": []
    },
    "zeus": {
      "name": "Zeus",
      "power": 8,
      "faction": "Grécia",
      "tags": []
    },
    "hades": {
      "name": "Hades",
      "power": 7,
      "faction": "Grécia",
      "tags": []
    },
    "lobo-omega": {
      "name": "Lobisomem Omega",
      "power": 1,
      "faction": "Monstros",
      "tags": [
        "monstro"
      ]
    },
    "lukyan": {
      "name": "Lukyan — Rei da Festa",
      "power": 3,
      "faction": "Alyns",
      "tags": []
    },
    "anubis": {
      "name": "Anúbis",
      "power": 5,
      "faction": "Egípcios",
      "tags": []
    },
    "odin": {
      "name": "Odin",
      "power": 8,
      "faction": "Nórdicos",
      "tags": []
    },
    "lukyan-rei-de-todos": {
      "name": "Lukyan — Rei de Todos",
      "power": 6,
      "faction": "Alyns",
      "tags": []
    },
    "minotauro": {
      "name": "Minotauro",
      "power": 3,
      "faction": "Grécia",
      "tags": [
        "monstro"
      ]
    },
    "apolo": {
      "name": "Apolo",
      "power": 6,
      "faction": "Grécia",
      "tags": []
    },
    "ra": {
      "name": "Rá",
      "power": 8,
      "faction": "Egípcios",
      "tags": []
    },
    "ragnar": {
      "name": "Ragnar",
      "power": 3,
      "faction": "Nórdicos",
      "tags": []
    },
    "afrodite": {
      "name": "Afrodite",
      "power": 5,
      "faction": "Grécia",
      "tags": []
    },
    "aquiles": {
      "name": "Aquiles",
      "power": 3,
      "faction": "Grécia",
      "tags": []
    },
    "seth": {
      "name": "Seth",
      "power": 4,
      "faction": "Egípcios",
      "tags": []
    },
    "osiris": {
      "name": "Osíris",
      "power": 6,
      "faction": "Egípcios",
      "tags": []
    },
    "thor": {
      "name": "Thor",
      "power": 6,
      "faction": "Nórdicos",
      "tags": []
    },
    "artemis": {
      "name": "Ártemis",
      "power": 5,
      "faction": "Grécia",
      "tags": []
    },
    "sobek": {
      "name": "Sobek",
      "power": 2,
      "faction": "Egípcios",
      "tags": []
    },
    "ares": {
      "name": "Ares",
      "power": 5,
      "faction": "Grécia",
      "tags": []
    },
    "beowulf": {
      "name": "Beowulf",
      "power": 3,
      "faction": "Nórdicos",
      "tags": []
    },
    "heimdall": {
      "name": "Heimdall",
      "power": 3,
      "faction": "Nórdicos",
      "tags": []
    },
    "dionisio": {
      "name": "Dionísio",
      "power": 4,
      "faction": "Grécia",
      "tags": []
    },
    "butter": {
      "name": "Butter",
      "power": 4,
      "faction": "Alyns",
      "tags": []
    },
    "hefesto": {
      "name": "Hefestos",
      "power": 4,
      "faction": "Grécia",
      "tags": []
    },
    "hercules": {
      "name": "Hércules",
      "power": 4,
      "faction": "Grécia",
      "tags": []
    },
    "hermes": {
      "name": "Hermes",
      "power": 3,
      "faction": "Grécia",
      "tags": []
    },
    "horus": {
      "name": "Hórus",
      "power": 4,
      "faction": "Egípcios",
      "tags": []
    },
    "lobo-beta": {
      "name": "Lobisomem Beta",
      "power": 2,
      "faction": "Monstros",
      "tags": [
        "monstro"
      ]
    },
    "isis": {
      "name": "Ísis",
      "power": 4,
      "faction": "Egípcios",
      "tags": []
    },
    "mulher": {
      "name": "Mulher",
      "power": 2,
      "faction": "Monstros",
      "tags": [
        "monstro"
      ]
    },
    "homem": {
      "name": "Homem",
      "power": 1,
      "faction": "Monstros",
      "tags": [
        "monstro"
      ]
    },
    "yggdrasil": {
      "name": "Yggdrasil",
      "power": 0,
      "faction": "Nórdicos",
      "tags": []
    },
    "alto-egito": {
      "name": "Alto Egito",
      "power": 0,
      "faction": "Egípcios",
      "tags": []
    },
    "baixo-egito": {
      "name": "Baixo Egito",
      "power": 0,
      "faction": "Egípcios",
      "tags": []
    },
    "bifrost": {
      "name": "Bifrost",
      "power": 0,
      "faction": "Nórdicos",
      "tags": []
    },
    "esparta": {
      "name": "Esparta",
      "power": 0,
      "faction": "Grécia",
      "tags": []
    },
    "labirinto-dedalos": {
      "name": "Labirinto de Dédalos",
      "power": 0,
      "faction": "Grécia",
      "tags": []
    },
    "nilfheim": {
      "name": "Nilfheim",
      "power": 0,
      "faction": "Nórdicos",
      "tags": []
    },
    "leonidas": {
      "name": "Leônidas",
      "faction": "Grécia",
      "tags": [
        "espartano"
      ]
    },
    "loki": {
      "name": "Loki",
      "faction": "Nórdicos",
      "tags": []
    },
    "gigante-de-gelo": {
      "name": "Gigante de Gelo",
      "faction": "Nórdicos",
      "tags": [
        "gigante-de-gelo"
      ]
    },
    "gigantes-de-gelo": {
      "name": "Gigantes de Gelo",
      "faction": "Nórdicos",
      "tags": [
        "gigante-de-gelo"
      ]
    }
  },
  "scope": "both-players",
  "stacking": "one-shared-terrain"
};
 window.MythicTerrainCards=data.cards;
 window.MythicTerrainRules={
  bonus(terrainId,card){
   if(!card)return 0;
   const meta=data.metadata[card.id]||card;
   for(const rule of data.rules[terrainId]||[]){
    if(rule.ids&&!rule.ids.includes(card.id))continue;
    if(rule.faction&&meta.faction!==rule.faction)continue;
    if(rule.excludeIds?.includes(card.id))continue;
    if(rule.tagsAny&&!rule.tagsAny.some(tag=>(meta.tags||[]).includes(tag)))continue;
    return rule.bonus;
   }
   return 0;
  }
 };
})();
