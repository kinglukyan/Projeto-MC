(() => {
 'use strict';
 const eventCard=c=>Boolean(c&&(c.climateClass==='event'||c.isClimateEvent||/^eclipse(?:-|$)/.test(c.id)||/evento/i.test(c.subtype||c.type||'')));
 window.MythicZoneRules={isEvent:eventCard,canReplace(incoming,current){if(!incoming)return false;if(!current)return true;const zone=c=>c.kind==='location'?'local':c.kind==='terrain'?'terrain':['event','climate','weather'].includes(c.kind)?'climate':null;if(!zone(incoming)||zone(incoming)!==zone(current))return false;return zone(incoming)!=='climate'||!eventCard(current)||eventCard(incoming);}};
})();
