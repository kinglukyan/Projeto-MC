(() => {
 'use strict';
 const eventCard=c=>Boolean(c&&(c.climateClass==='event'||c.isClimateEvent||/^eclipse(?:-|$)/.test(c.id)||/evento/i.test(c.subtype||c.type||'')));
 window.MythicZoneRules={isEvent:eventCard,canReplace(incoming,current){if(!incoming)return false;if(!current)return true;const zone=c=>c.kind==='location'?'local':c.kind==='terrain'?'terrain':['event','climate','weather'].includes(c.kind)?'climate':null;if(!zone(incoming)||zone(incoming)!==zone(current))return false;return zone(incoming)!=='climate'||!eventCard(current)||eventCard(incoming);}};
 window.MythicEclipseForms={
  formFor(original,climate,card){
   if(climate==='eclipse-solar')return {'lobo-alfa':'mulher','lobo-beta':'homem','lobo-omega':'homem'}[original]||original;
   if(climate==='eclipse-lunar'&&['monstros','monstro'].includes(String(card?.faction||'').trim().toLocaleLowerCase('pt-BR')))return {mulher:'lobo-alfa',homem:'lobo-beta'}[original]||original;
   return original;
  }
 };
})();
