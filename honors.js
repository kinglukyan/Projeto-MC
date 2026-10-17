#view-profile .equipped-honor-title{margin:12px 0 8px;color:#f2d486;font:700 15px 'Mythic Display',Georgia,serif}
.featured-medals{display:flex;gap:9px;flex-wrap:wrap;margin-top:10px}
.featured-medal{display:grid;place-items:center;width:32px;height:36px;border:1px solid #e6c076;border-radius:50% 50% 40% 40%;background:radial-gradient(circle,#41576e,#0e1c29);box-shadow:0 0 10px #ba95452a;color:#f1ce7e;font-size:21px}
.sidebar-honor-title{display:block;color:#e7c67c!important;font-size:9px!important;margin-top:5px;overflow-wrap:anywhere}
body.mythic-rework #view-profile .legend-grid>.honor-panel{grid-column:1/-1}
#view-profile .honor-panel header{flex-wrap:wrap}
#view-profile .honor-panel header>small{display:block;color:#9fb6c8;font-size:10px}
.honor-tabs{display:flex;gap:8px;margin:4px 0 12px}
.honor-tabs button{padding:10px 18px;border:1px solid #b18b4a66;border-radius:3px;background:#0c1925;color:#a7bed0;cursor:pointer}
.honor-tabs button[aria-pressed="true"]{background:#3d3223;color:#f3db9e;border-color:#d4ad65}
.honor-status{min-height:20px;color:#a9c1d3;font-size:11px;line-height:1.8}
.honor-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:14px}
.honor-card{display:flex;flex-direction:column;align-items:center;gap:10px;text-align:center;padding:20px 14px;border:1px solid #81704f77;border-radius:5px;background:linear-gradient(145deg,#1a2b3a,#09121e)}
.honor-card.unlocked{border-color:#cda96399}
.honor-card.locked .honor-emblem{filter:grayscale(1);opacity:.5}
.honor-emblem{display:grid;place-items:center;width:60px;height:68px;border:2px solid #cfab60;border-radius:50% 50% 36% 36%;background:radial-gradient(circle,#52687a,#142335);box-shadow:0 0 0 4px #a7863f20;color:#f4d895;font-size:34px}
.honor-card>b{color:#eed8a3;font:700 13px 'Mythic Display',Georgia,serif}
.honor-card>small{color:#a8bdca;font-size:10px;line-height:1.6;min-height:32px}
.honor-card progress{width:100%;height:6px;accent-color:#e3bb65}
.honor-progress{color:#a9c7d7;font-size:9px}
.honor-card button{width:100%;margin-top:auto;font-size:10px}
.sign-out-account{margin-top:12px;border-color:#b3705a88!important;color:#edb09c!important}
.sidebar-bottom>.sign-out-account{width:100%;min-height:35px;font-size:10px}
.friend-honors{display:flex;justify-content:space-between;align-items:center;gap:16px;padding:10px 0;color:#ecd391}
@media(max-width:640px){.honor-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.honor-card{padding:16px 8px}.honor-card>b{font-size:11px}}
