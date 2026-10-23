/* Approved first-area dialogue and outcome scenes. */
window.MythicAtlasDialogueData={
  "fps": 30,
  "frameHold": 7,
  "textCharacterMs": 28,
  "reactionHoldMs": 1800,
  "characters": {
    "aquiles": {
      "name": "Aquiles",
      "location": "Grécia · Santuário dos Heróis",
      "description": "Aquiles, guerreiro de cabelos loiros, armadura dourada e elmo de crista vermelha.",
      "images": {
        "normal": "assets/atlas-dialogue/aquiles-normal.png",
        "speaking": "assets/atlas-dialogue/aquiles-falando.png",
        "angry": "assets/atlas-dialogue/aquiles-bravo.png",
        "laughing": "assets/atlas-dialogue/aquiles-rindo.png"
      },
      "script": {
        "opening": {
          "text": "Olá, soldado, você também viu aquela explosão gigantesca no céu?",
          "expression": "normal",
          "choices": [
            {
              "text": "Sim, eu vi. Você sabe o que é?",
              "next": "question"
            },
            {
              "text": "Não vi, não. Mas onde estamos?",
              "next": "question"
            }
          ]
        },
        "question": {
          "text": "Como assim, onde estamos? Peraí, você é um soldado meu ou...?",
          "expression": "normal",
          "choices": [
            {
              "text": "Sou um soldado seu, sim.",
              "next": "soldier"
            },
            {
              "text": "Sou um viajante de passagem, buscando conhecimento.",
              "next": "traveler"
            }
          ]
        },
        "soldier": {
          "text": "Aquiles faz uma cara de bravo.",
          "expression": "angry",
          "choices": [],
          "narration": true,
          "duel": true
        },
        "traveler": {
          "text": "Aquiles solta uma risada.",
          "expression": "laughing",
          "choices": [],
          "narration": true,
          "duel": true
        }
      },
      "outcomes": {
        "victory": {
          "text": "Você luta bem para um viajante! Se descobrir alguma coisa sobre aquela explosão, volte para me contar. Quero uma revanche quando o céu parar de cair.",
          "expression": "laughing",
          "choices": []
        },
        "defeat": {
          "text": "Você se precipitou. Eu também já fiz isso... e geralmente havia alguém por perto para reclamar. Respire, prepare-se e tente outra vez.",
          "expression": "normal",
          "choices": []
        }
      }
    },
    "hercules": {
      "name": "Hércules",
      "description": "Hércules, herói musculoso com a pele do leão de Nemeia.",
      "script": {
        "opening": {
          "text": "Você veio pelo caminho de Aquiles? E ainda está inteiro? Já gostei de você!",
          "expression": "normal",
          "choices": [
            {
              "text": "Ele parecia mais preocupado com a explosão do que comigo.",
              "next": "sky"
            },
            {
              "text": "Foi por pouco. Você também vai querer me enfrentar?",
              "next": "fight"
            }
          ]
        },
        "sky": {
          "text": "Eu também vi. Por um instante, pareceu que o próprio céu estava sendo rasgado.",
          "expression": "serious",
          "choices": [
            {
              "text": "Continuar",
              "next": "question"
            }
          ]
        },
        "fight": {
          "text": "Claro! Mas pode ficar tranquilo: hoje o trabalho difícil vai ser meu. Estou tentando pegar leve.",
          "expression": "laughing",
          "choices": [
            {
              "text": "Continuar",
              "next": "question"
            }
          ]
        },
        "question": {
          "text": "Desde aquela luz, tenho encontrado coisas que não pertencem a estas terras. Quero descobrir se você é uma delas.",
          "expression": "normal",
          "choices": [
            {
              "text": "Pode perguntar. Não precisa resolver tudo lutando.",
              "next": "wise"
            },
            {
              "text": "Então venha descobrir.",
              "next": "ready"
            }
          ]
        },
        "wise": {
          "text": "Perguntar é com os sábios. Eu aprendo melhor na prática!",
          "expression": "smiling",
          "choices": [],
          "duel": true
        },
        "ready": {
          "text": "Essa é a disposição!",
          "expression": "laughing",
          "choices": [],
          "duel": true
        }
      },
      "outcomes": {
        "victory": {
          "text": "Essa eu vou ter que contar! Talvez eu deixe de fora a parte em que perdi... Estou brincando! Você conquistou essa vitória.",
          "expression": "laughing",
          "choices": []
        },
        "defeat": {
          "text": "Vamos, levante! Meus trabalhos também não se resolveram na primeira tentativa. Qual foi a parte mais difícil? É por ela que você deve começar.",
          "expression": "smiling",
          "choices": []
        }
      },
      "location": "Grécia · Santuário dos Heróis",
      "sheet": "assets/atlas-dialogue/hercules-expressoes.png",
      "cells": {
        "normal": [
          0,
          0
        ],
        "speaking": [
          1,
          0
        ],
        "smiling": [
          2,
          0
        ],
        "serious": [
          0,
          1
        ],
        "laughing": [
          1,
          1
        ],
        "surprised": [
          2,
          1
        ]
      }
    },
    "hermes": {
      "name": "Hermes",
      "description": "Hermes, mensageiro de elmo alado dourado e manto turquesa.",
      "script": {
        "opening": {
          "text": "Finalmente! Estou procurando você desde... bom, desde alguns instantes atrás. Para mim, isso é bastante tempo.",
          "expression": "normal",
          "choices": [
            {
              "text": "Como você sabe quem eu sou?",
              "next": "known"
            },
            {
              "text": "Se veio entregar uma mensagem, pode falar.",
              "next": "message"
            }
          ]
        },
        "known": {
          "text": "Um desconhecido aparece depois de uma explosão no céu e começa a enfrentar heróis. Você não está sendo muito discreto.",
          "expression": "smiling",
          "choices": [
            {
              "text": "Continuar",
              "next": "question"
            }
          ]
        },
        "message": {
          "text": "Esse é o problema. Recebi ordens de levar mensagens a lugares que já não encontro onde deveriam estar.",
          "expression": "serious",
          "choices": [
            {
              "text": "Continuar",
              "next": "question"
            }
          ]
        },
        "question": {
          "text": "Os caminhos estão estranhos. Antes de indicar o seu, preciso saber se você consegue tomar uma decisão sem ficar parado pensando para sempre.",
          "expression": "normal",
          "choices": [
            {
              "text": "Pensar antes de agir costuma ajudar.",
              "next": "think"
            },
            {
              "text": "Você fala demais para alguém com tanta pressa.",
              "next": "fast"
            }
          ]
        },
        "think": {
          "text": "Ótimo! Vamos descobrir quanto tempo você precisa.",
          "expression": "laughing",
          "choices": [],
          "duel": true
        },
        "fast": {
          "text": "Gostei. Sua língua acompanha os seus pés?",
          "expression": "surprised",
          "choices": [],
          "duel": true
        }
      },
      "outcomes": {
        "victory": {
          "text": "Eu vi sua jogada chegando e mesmo assim caí nela. Isso vai ficar entre nós, certo? Pode seguir. Tenho algumas mensagens para entregar... bem longe daqui.",
          "expression": "surprised",
          "choices": []
        },
        "defeat": {
          "text": "Você ficou tão ocupado acompanhando meus movimentos que esqueceu dos seus. Na próxima, faça com que eu precise acompanhar você.",
          "expression": "smiling",
          "choices": []
        }
      },
      "location": "Grécia · Santuário dos Heróis",
      "sheet": "assets/atlas-dialogue/hermes-expressoes.png",
      "cells": {
        "normal": [
          0,
          0
        ],
        "speaking": [
          1,
          0
        ],
        "smiling": [
          2,
          0
        ],
        "serious": [
          0,
          1
        ],
        "laughing": [
          1,
          1
        ],
        "surprised": [
          2,
          1
        ]
      }
    },
    "athena": {
      "name": "Athena",
      "description": "Athena, deusa de elmo com crista branca, armadura dourada e manto azul.",
      "script": {
        "opening": {
          "text": "Uma luz rasga o céu e, pouco depois, um desconhecido surge enfrentando nossos heróis. Você entende por que sua presença desperta perguntas?",
          "expression": "normal",
          "choices": [
            {
              "text": "Eu também estou procurando respostas.",
              "next": "answers"
            },
            {
              "text": "Se já sabe por onde passei, talvez saiba de onde vim.",
              "next": "origin"
            }
          ]
        },
        "answers": {
          "text": "Então comece pelo que viu. Não pelo que imagina ter acontecido. Em momentos como este, confundir as duas coisas pode nos custar caro.",
          "expression": "serious",
          "choices": [
            {
              "text": "Continuar",
              "next": "watch"
            }
          ]
        },
        "origin": {
          "text": "Sei por onde você caminhou. Isso ainda não me diz o que trouxe você até aqui.",
          "expression": "smiling",
          "choices": [
            {
              "text": "Continuar",
              "next": "watch"
            }
          ]
        },
        "watch": {
          "text": "Desde a explosão, nossos vigias descrevem montanhas que nunca existiram e estrelas que não reconhecem. Preciso de alguém capaz de observar antes de agir.",
          "expression": "normal",
          "choices": [
            {
              "text": "E como pretende descobrir se sou essa pessoa?",
              "next": "question"
            }
          ]
        },
        "question": {
          "text": "Você passou por Aquiles e Hércules. Quero ver quais decisões tomou para chegar até aqui.",
          "expression": "normal",
          "choices": [
            {
              "text": "Vou mostrar o que aprendi.",
              "next": "learn"
            },
            {
              "text": "Também vai resolver isso com um duelo?",
              "next": "pressure"
            }
          ]
        },
        "learn": {
          "text": "Ótimo. E esteja disposto a aprender algo mais.",
          "expression": "smiling",
          "choices": [],
          "duel": true
        },
        "pressure": {
          "text": "Durante uma conversa, você pode escolher o que me contar. Sob pressão, suas escolhas costumam ser mais sinceras.",
          "expression": "surprised",
          "choices": [],
          "duel": true
        }
      },
      "outcomes": {
        "victory": {
          "text": "Você soube se adaptar. Continue observando o que mudou nestas terras. Se encontrar algo que pareça não pertencer a este mundo, procure-me.",
          "expression": "smiling",
          "choices": []
        },
        "defeat": {
          "text": "Volte quando estiver pronto. Antes disso, pense na escolha que mais lhe custou nesta partida. Podemos começar por ela.",
          "expression": "normal",
          "choices": []
        }
      },
      "location": "Grécia · Santuário dos Heróis",
      "sheet": "assets/atlas-dialogue/athena-expressoes.png",
      "cells": {
        "normal": [
          0,
          0
        ],
        "speaking": [
          1,
          0
        ],
        "smiling": [
          2,
          0
        ],
        "serious": [
          0,
          1
        ],
        "laughing": [
          1,
          1
        ],
        "surprised": [
          2,
          1
        ]
      }
    },
    "soldado-esparta": {
      "name": "Soldado de Esparta",
      "description": "Soldado espartano de elmo de bronze, crista vermelha e capa vermelha.",
      "script": {
        "opening": {
          "text": "Alto! Identifique-se. Esta passagem está sob proteção de Esparta.",
          "expression": "serious",
          "choices": [
            {
              "text": "Aquiles me chamou de soldado. Isso ajuda?",
              "next": "soldier"
            },
            {
              "text": "Sou um viajante. Estou tentando entender o que aconteceu.",
              "next": "traveler"
            }
          ]
        },
        "soldier": {
          "text": "Aquiles chama qualquer pessoa de soldado quando precisa de alguma coisa.",
          "expression": "surprised",
          "choices": [
            {
              "text": "Continuar",
              "next": "question"
            }
          ]
        },
        "traveler": {
          "text": "Então temos o mesmo objetivo. Minha patrulha viu aquela luz e, desde então, dois dos nossos não voltaram.",
          "expression": "serious",
          "choices": [
            {
              "text": "Continuar",
              "next": "question"
            }
          ]
        },
        "question": {
          "text": "Vou procurá-los. Se pretende atravessar esta passagem, preciso saber se posso contar com você quando a situação apertar.",
          "expression": "normal",
          "choices": [
            {
              "text": "Não vou abandonar ninguém.",
              "next": "loyal"
            },
            {
              "text": "Já enfrentei dois heróis, um mensageiro e uma deusa. Estou preparado.",
              "next": "ready"
            }
          ]
        },
        "loyal": {
          "text": "Boa resposta. Agora mostre que consegue sustentá-la.",
          "expression": "smiling",
          "choices": [],
          "duel": true
        },
        "ready": {
          "text": "Enfrentar alguém é uma coisa. Saber quando continuar ou recuar é outra.",
          "expression": "serious",
          "choices": [],
          "duel": true
        }
      },
      "outcomes": {
        "victory": {
          "text": "Você pode passar. Se encontrar minha patrulha... diga que ainda estamos procurando por eles. E cuidado em Esparta: depois daquela explosão, nem todos recebem viajantes de braços abertos.",
          "expression": "smiling",
          "choices": []
        },
        "defeat": {
          "text": "Você resistiu bem, mas gastou suas forças cedo demais. Descanse. Quando voltar, quero ver você guardar o suficiente para terminar a luta.",
          "expression": "normal",
          "choices": []
        }
      },
      "location": "Grécia · Santuário dos Heróis",
      "sheet": "assets/atlas-dialogue/soldado-esparta-expressoes.png",
      "cells": {
        "normal": [
          0,
          0
        ],
        "speaking": [
          1,
          0
        ],
        "smiling": [
          2,
          0
        ],
        "serious": [
          0,
          1
        ],
        "laughing": [
          1,
          1
        ],
        "surprised": [
          2,
          1
        ]
      }
    }
  }
};
