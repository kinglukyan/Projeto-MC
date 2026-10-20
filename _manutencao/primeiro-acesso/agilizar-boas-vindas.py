from pathlib import Path
root=Path('outputs/Mythic-Clash-Completo')
p=root/'welcome.js';s=p.read_text(encoding='utf-8')
s=s.replace("const PACK='assets/onboarding/starter-pack.png'", "const PACK=window.MythicEntryMedia?.optimized?.['assets/onboarding/starter-pack.png']||'assets/onboarding/starter-pack.png'")
s=s.replace("const picture=(src,alt='',cls='')=>{const n=el('img',cls);n.src=window.MythicSecurity.assetUrl(src);", "const picture=(src,alt='',cls='',full=false)=>{const n=el('img',cls);n.src=window.MythicSecurity.assetUrl(full?src:window.MythicEntryMedia?.byArt?.[src]||src);")
s=s.replace("let root=null,stage=null", "let collectionRefresh=null;\n let root=null,stage=null")
s=s.replace("function reset(){generation++;", "function reset(){collectionRefresh=null;generation++;")
s=s.replace("packReady=preload(PACK);for(const path of paths){preload(path.image);preload(path.scene);}", "packReady=preload(PACK);")
s=s.replace("await window.MythicOnline.refreshProfile();if(!current(token))return;packScreen();", "collectionRefresh=window.MythicOnline.refreshProfile().then(()=>true,()=>false);if(!current(token))return;packScreen();")
s=s.replace("packReady=Promise.all([preload(PACK),preload(BACK),...cards().map(c=>preload(c.art||BACK))]);", "packReady=Promise.all([preload(PACK),preload(BACK)]);for(const c of cards().slice(0,3))preload(window.MythicEntryMedia?.byArt?.[c.art]||c.art||BACK);")
s=s.replace("await packReady;if(!current(token)", "await Promise.race([packReady,new Promise(resolve=>setTimeout(resolve,500))]);if(!current(token)")
s=s.replace("n.append(picture(c.art||BACK,c.name));fan.append(n);", "n.append(picture(c.art||BACK,c.name,'',d===0));fan.append(n);")
s=s.replace("await window.MythicOnline.completeWelcome();await window.MythicOnline.refreshProfile();", "await window.MythicOnline.completeWelcome();if(!collectionRefresh||!await collectionRefresh)await window.MythicOnline.refreshProfile();")
p.write_text(s,encoding='utf-8')
p=root/'public-hall.js';s=p.read_text(encoding='utf-8');s=s.replace("n.src=asset(src);", "n.src=asset(window.MythicEntryMedia?.byArt?.[src]||window.MythicEntryMedia?.optimized?.[src]||src);")
s=s.replace("node.style.backgroundImage='url(\"'+b.atlas+'\")';", "if(window.MythicStartup)window.MythicStartup.deferBackground(node,b.atlas);else node.style.backgroundImage='url(\"'+b.atlas+'\")';")
s=s.replace("node.style.backgroundImage='url(\"'+asset(card(id)?.hologram||card(id)?.art)+'\")';", "const src=asset(card(id)?.hologram||card(id)?.art);if(window.MythicStartup)window.MythicStartup.deferBackground(node,src);else node.style.backgroundImage='url(\"'+src+'\")';")
p.write_text(s,encoding='utf-8')
# The account's ownership data is critical; rendering the entire store is not.
p=root/'online.js';s=p.read_text(encoding='utf-8')
s=s.replace("if(session){window.MythicPortal?.checkAccess?.().then(ok=>{if(ok)window.MythicWelcome?.begin(session.user);});startPresence();loadProfile().catch(()=>{});loadCommunityHub().catch(()=>{});loadFriends();", "if(session){startPresence();loadProfile().catch(()=>{});")
s=s.replace('pendingFriendInviteCode=null;loadStore().catch(()=>{});activeFriend=null;', 'pendingFriendInviteCode=null;activeFriend=null;')
s=s.replace('await Promise.all([loadStore(),loadCardCopies()]);', 'await Promise.all([loadOwnedItems(),loadCardCopies()]);')
s=s.replace('    loadHistory();loadProfileAnalytics(uid,"profile");loadPlayerHonors();', '    scheduleAccountExtras(uid);')
marker='  async function loadStore(){'
insert='''  async function loadOwnedItems(){
    const uid=session?.user?.id;if(!uid||!supabase)return;
    const {data,error}=await supabase.from('player_inventory').select('item_id').eq('player_id',uid);
    if(session?.user?.id!==uid)return;if(error)throw Error(displayError(error));
    ownedItems=new Set((data||[]).map(item=>item.item_id));paintProfileAvatars();renderAvatarPicker();
  }
  let extrasTimer=null;
  function scheduleAccountExtras(uid){
    clearTimeout(extrasTimer);
    const run=()=>{if(uid!==session?.user?.id||!accountReady)return;
      if(window.MythicWelcome?.isOpen?.()||document.body.classList.contains('public-home-open')){extrasTimer=setTimeout(run,1500);return;}
      loadStore().catch(()=>{});loadCommunityHub().catch(()=>{});loadFriends().catch(()=>{});loadHistory();loadProfileAnalytics(uid,'profile');loadPlayerHonors();
    };extrasTimer=setTimeout(run,200);
  }
'''
if marker not in s:raise ValueError('store marker')
s=s.replace(marker,insert+marker)
p.write_text(s,encoding='utf-8')
print('Downloads e consultas fora do caminho das boas-vindas.')
