"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[2],{3905:(e,n,t)=>{t.d(n,{Zo:()=>d,kt:()=>y});var r=t(67294);function a(e,n,t){return n in e?Object.defineProperty(e,n,{value:t,enumerable:!0,configurable:!0,writable:!0}):e[n]=t,e}function o(e,n){var t=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);n&&(r=r.filter((function(n){return Object.getOwnPropertyDescriptor(e,n).enumerable}))),t.push.apply(t,r)}return t}function c(e){for(var n=1;n<arguments.length;n++){var t=null!=arguments[n]?arguments[n]:{};n%2?o(Object(t),!0).forEach((function(n){a(e,n,t[n])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(t)):o(Object(t)).forEach((function(n){Object.defineProperty(e,n,Object.getOwnPropertyDescriptor(t,n))}))}return e}function l(e,n){if(null==e)return{};var t,r,a=function(e,n){if(null==e)return{};var t,r,a={},o=Object.keys(e);for(r=0;r<o.length;r++)t=o[r],n.indexOf(t)>=0||(a[t]=e[t]);return a}(e,n);if(Object.getOwnPropertySymbols){var o=Object.getOwnPropertySymbols(e);for(r=0;r<o.length;r++)t=o[r],n.indexOf(t)>=0||Object.prototype.propertyIsEnumerable.call(e,t)&&(a[t]=e[t])}return a}var i=r.createContext({}),s=function(e){var n=r.useContext(i),t=n;return e&&(t="function"==typeof e?e(n):c(c({},n),e)),t},d=function(e){var n=s(e.components);return r.createElement(i.Provider,{value:n},e.children)},u="mdxType",p={inlineCode:"code",wrapper:function(e){var n=e.children;return r.createElement(r.Fragment,{},n)}},P=r.forwardRef((function(e,n){var t=e.components,a=e.mdxType,o=e.originalType,i=e.parentName,d=l(e,["components","mdxType","originalType","parentName"]),u=s(t),P=a,y=u["".concat(i,".").concat(P)]||u[P]||p[P]||o;return t?r.createElement(y,c(c({ref:n},d),{},{components:t})):r.createElement(y,c({ref:n},d))}));function y(e,n){var t=arguments,a=n&&n.mdxType;if("string"==typeof e||a){var o=t.length,c=new Array(o);c[0]=P;var l={};for(var i in n)hasOwnProperty.call(n,i)&&(l[i]=n[i]);l.originalType=e,l[u]="string"==typeof e?e:a,c[1]=l;for(var s=2;s<o;s++)c[s]=t[s];return r.createElement.apply(null,c)}return r.createElement.apply(null,t)}P.displayName="MDXCreateElement"},24875:(e,n,t)=>{t.r(n),t.d(n,{assets:()=>i,contentTitle:()=>c,default:()=>p,frontMatter:()=>o,metadata:()=>l,toc:()=>s});var r=t(87462),a=(t(67294),t(3905));const o={sidebar_position:4},c="Handling Developer Products",l={unversionedId:"DeveloperProduct",id:"DeveloperProduct",title:"Handling Developer Products",description:"The following code is an example of how you would handle players purchasing developer products:",source:"@site/docs/DeveloperProduct.md",sourceDirName:".",slug:"/DeveloperProduct",permalink:"/lapis/docs/DeveloperProduct",draft:!1,editUrl:"https://github.com/nezuo/lapis/edit/master/docs/DeveloperProduct.md",tags:[],version:"current",sidebarPosition:4,frontMatter:{sidebar_position:4},sidebar:"defaultSidebar",previous:{title:"Writing Migrations",permalink:"/lapis/docs/Migrations"}},i={},s=[],d={toc:s},u="wrapper";function p(e){let{components:n,...t}=e;return(0,a.kt)(u,(0,r.Z)({},d,t,{components:n,mdxType:"MDXLayout"}),(0,a.kt)("h1",{id:"handling-developer-products"},"Handling Developer Products"),(0,a.kt)("p",null,"The following code is an example of how you would handle players purchasing developer products:"),(0,a.kt)("pre",null,(0,a.kt)("code",{parentName:"pre",className:"language-lua"},"local DEFAULT_DATA = { coins = 100, recentPurchases = {} }\nlocal RECENT_PURCHASES_LIMIT = 100\nlocal PRODUCTS = {\n    [12345] = function(oldData)\n        -- Product callbacks return a new version of the data.\n        return Sift.Dictionary.merge(oldData, {\n            coins = oldData.coins + 100,\n        })\n    end,\n}\n\nlocal collection = Lapis.createCollection(\"PlayerData\", {\n    defaultData = DEFAULT_DATA,\n    validate = t.strictInterface({ coins = t.integer, recentPurchases = t.array(t.string) }),\n})\n\nlocal documents = {}\n\nlocal function onPlayerAdded(player: Player)\n    collection\n        :load(`Player{player.UserId}`, { player.UserId })\n        :andThen(function(document)\n            if player.Parent == nil then\n                document:close():catch(warn)\n                return\n            end\n\n            documents[player] = document\n        end)\n        :catch(function(message)\n            warn(`Player {player.Name}'s data failed to load: {message}`)\n            player:Kick(\"Data failed to load.\")\n        end)\nend\n\nlocal function onPlayerRemoving(player: Player)\n    local document = documents[player]\n\n    if document ~= nil then\n        documents[player] = nil\n        document:close():catch(warn)\n    end\nend\n\nlocal function processReceipt(receiptInfo): Enum.ProductPurchaseDecision\n    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)\n    if player == nil then\n        return Enum.ProductPurchaseDecision.NotProcessedYet\n    end\n\n    while documents[player] == nil and player.Parent ~= nil do\n        -- Wait until the document loads or the player leaves.\n        task.wait()\n    end\n\n    local document = documents[player]\n    if document == nil then\n        return Enum.ProductPurchaseDecision.NotProcessedYet\n    end\n\n    local data = document:read()\n\n    if table.find(data.recentPurchases, receiptInfo.PurchaseId) then\n        -- The purchase has been added to the player's data, but it might not have saved yet.\n        local saveOk = document:save():await()\n\n        if saveOk then\n            return Enum.ProductPurchaseDecision.PurchaseGranted\n        else\n            return Enum.ProductPurchaseDecision.NotProcessedYet\n        end\n    end\n\n    -- The product callback must not yield. Otherwise, it can return outdated data and overwrite new changes.\n    local productOk, dataWithProduct = pcall(PRODUCTS[receiptInfo.ProductId], data)\n    if not productOk then\n        return Enum.ProductPurchaseDecision.NotProcessedYet\n    end\n\n    local newRecentPurchases = Sift.Array.push(data.recentPurchases, receiptInfo.PurchaseId)\n    if #newRecentPurchases > RECENT_PURCHASES_LIMIT then\n        newRecentPurchases = Sift.Array.shift(newRecentPurchases, #newRecentPurchases - RECENT_PURCHASES_LIMIT)\n    end\n\n    document:write(Sift.Dictionary.merge(dataWithProduct, {\n        recentPurchases = newRecentPurchases,\n    }))\n\n    local saveOk = document:save():await()\n    if not saveOk then\n        return Enum.ProductPurchaseDecision.NotProcessedYet\n    end\n\n    return Enum.ProductPurchaseDecision.PurchaseGranted\nend\n\n-- The ProcessReceipt callback must be set before the Players.PlayerAdded signal is fired, otherwise the player's\n-- existing receipts won't be processed when they join.\nMarketplaceService.ProcessReceipt = processReceipt\n\nPlayers.PlayerAdded:Connect(onPlayerAdded)\nPlayers.PlayerRemoving:Connect(onPlayerRemoving)\n\nfor _, player in Players:GetPlayers() do\n    onPlayerAdded(player)\nend\n")))}p.isMDXComponent=!0}}]);