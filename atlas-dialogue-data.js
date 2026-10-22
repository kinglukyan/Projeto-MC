/* Atlas stories are local presentation data. A duel starts only after the last choice. */
window.MythicAtlasDialogueData={
 fps:30,
 frameHold:7,
 textCharacterMs:28,
 reactionHoldMs:1800,
 characters:{
  aquiles:{
   name:'Aquiles',
   location:'Grécia · Santuário dos Heróis',
   images:{
    normal:'assets/atlas-dialogue/aquiles-normal.png',
    speaking:'assets/atlas-dialogue/aquiles-falando.png',
    angry:'assets/atlas-dialogue/aquiles-bravo.png',
    laughing:'assets/atlas-dialogue/aquiles-rindo.png'
   },
   opening:{
    text:'Olá, soldado, você também viu aquela explosão gigantesca no céu?',
    choices:[
     {id:'saw',text:'Sim, eu vi, você sabe o que é?'},
     {id:'lost',text:'Não vi não, mas onde estamos?'}
    ]
   },
   question:{
    text:'Como assim, onde estamos? Peraí, você é um soldado meu ou...?',
    choices:[
     {id:'soldier',text:'Sou um soldado seu sim',expression:'angry',reaction:'Aquiles faz uma cara de bravo.'},
     {id:'traveler',text:'Sou um viajante de passagem, buscando conhecimento',expression:'laughing',reaction:'Aquiles solta uma risada.'}
    ]
   }
  }
 }
};
