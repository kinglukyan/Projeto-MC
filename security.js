(() => {
  'use strict';
  const escapeHTML=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function assetUrl(value,fallback=''){
    if(typeof value!=='string'||!value.trim()||value.length>8192)return fallback;
    try{
      const url=new URL(value,location.href);
      if(url.username||url.password||!['https:','http:'].includes(url.protocol))return fallback;
      if(url.protocol==='http:'&&url.origin!==location.origin)return fallback;
      return url.href.replace(/["'<>`\\]/g,c=>"%"+c.charCodeAt(0).toString(16).toUpperCase());
    }catch{return fallback;}
  }
  const storage={
    get(key,fallback=null){try{return localStorage.getItem(key)??fallback;}catch{return fallback;}},
    set(key,value){try{localStorage.setItem(key,String(value));return true;}catch{return false;}}
  };
  window.MythicSecurity=Object.freeze({escapeHTML,assetUrl,storage});
})();
