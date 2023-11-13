"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[28],{24936:e=>{e.exports=JSON.parse('{"functions":[{"name":"read","desc":"Returns the document\'s data.","params":[],"returns":[{"desc":"","lua_type":"any"}],"function_type":"method","source":{"line":45,"path":"src/Document.lua"}},{"name":"write","desc":"Writes the document\'s data.\\n\\n:::warning\\nThrows an error if the document was closed or if the data is invalid.\\n:::","params":[{"name":"data","desc":"","lua_type":"any"}],"returns":[],"function_type":"method","source":{"line":58,"path":"src/Document.lua"}},{"name":"addUserId","desc":"Adds a user id to the document\'s `DataStoreKeyInfo:GetUserIds()`. The change won\'t apply until the document is saved or closed.\\n\\nIf the user id is already associated with the document the method won\'t do anything.","params":[{"name":"userId","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":74,"path":"src/Document.lua"}},{"name":"removeUserId","desc":"Removes a user id from the document\'s `DataStoreKeyInfo:GetUserIds()`. The change won\'t apply until the document is saved or closed.\\n\\nIf the user id is not associated with the document the method won\'t do anything.","params":[{"name":"userId","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":87,"path":"src/Document.lua"}},{"name":"save","desc":"Saves the document\'s data. If the save is throttled and you call it multiple times, it will save only once with the latest data.\\n\\n:::warning\\nThrows an error if the document was closed.\\n:::\\n\\n:::warning\\nIf the beforeSave callback errors, the returned promise will reject and the data will not be saved.\\n:::","params":[],"returns":[{"desc":"","lua_type":"Promise<()>"}],"function_type":"method","source":{"line":108,"path":"src/Document.lua"}},{"name":"close","desc":"Saves the document and removes the session lock. The document is unusable after calling. If a save is currently in\\nprogress it will close the document instead.\\n\\n:::warning\\nThrows an error if the document was closed.\\n:::\\n\\n:::warning\\nIf the beforeSave or beforeClose callbacks error, the returned promise will reject and the data will not be saved.\\n:::","params":[],"returns":[{"desc":"","lua_type":"Promise<()>"}],"function_type":"method","source":{"line":141,"path":"src/Document.lua"}},{"name":"beforeSave","desc":"Sets a callback that is run inside `document:save` and `document:close` before it saves. The document can be read and written to in the\\ncallback.\\n\\nThe callback will run before the beforeClose callback inside of `document:close`.\\n\\n:::warning\\nThrows an error if it was called previously.\\n:::","params":[{"name":"callback","desc":"","lua_type":"() -> ()"}],"returns":[],"function_type":"method","source":{"line":184,"path":"src/Document.lua"}},{"name":"beforeClose","desc":"Sets a callback that is run inside `document:close` before it saves. The document can be read and written to in the\\ncallback.\\n\\n:::warning\\nThrows an error if it was called previously.\\n:::","params":[{"name":"callback","desc":"","lua_type":"() -> ()"}],"returns":[],"function_type":"method","source":{"line":200,"path":"src/Document.lua"}}],"properties":[],"types":[],"name":"Document","desc":"","source":{"line":24,"path":"src/Document.lua"}}')}}]);