(() => {
 'use strict';
 function from(value){
  const xp=Math.max(0,Math.floor(Number(value)||0));
  const level=xp<100?1:2+Math.floor((xp-100)/150);
  const start=level===1?0:100+(level-2)*150,end=level===1?100:start+150;
  return {xp,level,start,end,within:xp-start,needed:end-start,remaining:end-xp};
 }
 window.MythicXP={from};
})();
