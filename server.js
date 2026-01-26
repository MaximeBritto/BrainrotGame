const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const WebSocket = require('ws');
const http = require('http');
const crypto = require('crypto');

const app = express();
const PORT = 3000;
const WS_PORT = 3001;

// Augmentation de la limite pour les gros envois
app.use(express.json({ limit: '50mb' }));
app.use(cors());

const ROOT_DIR = path.join(__dirname, 'GamePlace');
const SHARED_FOLDERS_CONFIG = path.join(ROOT_DIR, 'shared_folders.json');

// Création du dossier racine au démarrage
if (!fs.existsSync(ROOT_DIR)) fs.mkdirSync(ROOT_DIR);
if (!fs.existsSync(path.join(ROOT_DIR, 'Scenes'))) fs.mkdirSync(path.join(ROOT_DIR, 'Scenes'));

// --------------------------------------------------------
// SYSTÈME DE DOSSIERS PARTAGÉS (Style Rojo multi-place)
// --------------------------------------------------------

// Charger la configuration des dossiers partagés
function loadSharedFoldersConfig() {
    if (fs.existsSync(SHARED_FOLDERS_CONFIG)) {
        try {
            return JSON.parse(fs.readFileSync(SHARED_FOLDERS_CONFIG, 'utf8'));
        } catch (e) {
            console.error('❌ Erreur lecture shared_folders.json:', e.message);
        }
    }
    // Configuration par défaut
    return {
        shared_folders: [],
        external_projects: [],
        settings: { auto_sync: true, watch_shared_folders: true, notify_on_change: true }
    };
}

// Sauvegarder la configuration des dossiers partagés
function saveSharedFoldersConfig(config) {
    try {
        fs.writeFileSync(SHARED_FOLDERS_CONFIG, JSON.stringify(config, null, '\t'));
        return true;
    } catch (e) {
        console.error('❌ Erreur écriture shared_folders.json:', e.message);
        return false;
    }
}

// Résoudre le chemin absolu d'un dossier partagé
function resolveSharedPath(relativePath) {
    // Si le chemin commence par ../, c'est relatif au dossier parent de ROOT_DIR
    if (relativePath.startsWith('../')) {
        return path.resolve(path.dirname(ROOT_DIR), relativePath.replace('../', ''));
    }
    // Sinon, c'est relatif à ROOT_DIR
    return path.resolve(ROOT_DIR, relativePath);
}

// Collecter les scripts depuis un dossier partagé
function collectSharedScripts(sharedFolder) {
    const scripts = [];
    const sourcePath = resolveSharedPath(sharedFolder.path);
    
    if (!fs.existsSync(sourcePath)) {
        console.warn(`⚠️ Dossier partagé introuvable: ${sourcePath}`);
        return scripts;
    }
    
    function walk(dir, relativePath = '') {
        const items = fs.readdirSync(dir);
        for (const item of items) {
            const fullPath = path.join(dir, item);
            const itemRelPath = relativePath ? relativePath + '/' + item : item;
            
            try {
                const stats = fs.statSync(fullPath);
                if (stats.isDirectory()) {
                    walk(fullPath, itemRelPath);
                } else if (item.endsWith('.lua')) {
                    const content = fs.readFileSync(fullPath, 'utf8');
                    const className = detectScriptType(itemRelPath, content);
                    
                    // Le chemin cible dans Roblox
                    const targetPath = sharedFolder.target + '/' + itemRelPath;
                    
                    scripts.push({
                        path: targetPath,
                        sourcePath: fullPath,
                        relativePath: itemRelPath,
                        sharedFolder: sharedFolder.name,
                        className: className,
                        content: content,
                        hash: computeHash(content),
                        lastModified: stats.mtime.getTime()
                    });
                }
            } catch (e) {
                console.error(`Erreur lecture ${fullPath}:`, e.message);
            }
        }
    }
    
    walk(sourcePath);
    return scripts;
}

// Collecter tous les scripts partagés activés
function getAllSharedScripts() {
    const config = loadSharedFoldersConfig();
    const allScripts = [];
    
    for (const folder of config.shared_folders || []) {
        if (folder.enabled) {
            const scripts = collectSharedScripts(folder);
            allScripts.push(...scripts);
        }
    }
    
    return allScripts;
}

// Créer tous les dossiers de services Roblox au démarrage (même vides)
const SERVICE_FOLDERS = ['ServerScriptService', 'ReplicatedStorage', 'StarterPlayer', 'StarterGui', 'Lighting'];
for (const folder of SERVICE_FOLDERS) {
    const folderPath = path.join(ROOT_DIR, folder);
    if (!fs.existsSync(folderPath)) {
        fs.mkdirSync(folderPath, { recursive: true });
        console.log(`📁 Dossier créé: ${folder}`);
    }
}

// --------------------------------------------------------
// UTILITAIRES - Hash et gestion des scripts globaux
// --------------------------------------------------------

// Détection intelligente du type de script
function detectScriptType(filePath, content) {
    const fileName = path.basename(filePath);
    const dirPath = filePath.toLowerCase();
    
    // 1. Extension explicite dans le nom (.client.lua, .server.lua, .local.lua, .module.lua)
    // PRIORITÉ ABSOLUE - Ces extensions définissent explicitement le type
    if (fileName.endsWith('.client.lua') || fileName.endsWith('.local.lua') || fileName.includes('.client.') || fileName.includes('.local.')) {
        return 'LocalScript';
    }
    if (fileName.endsWith('.server.lua') || fileName.includes('.server.')) {
        return 'Script';
    }
    if (fileName.endsWith('.module.lua') || fileName.includes('.module.')) {
        return 'ModuleScript';
    }
    
    // 2. Nom contient le type
    if (fileName.includes('LocalScript') || fileName === 'LocalScript.lua') {
        return 'LocalScript';
    }
    if (fileName.includes('ModuleScript') || fileName === 'ModuleScript.lua') {
        return 'ModuleScript';
    }
    
    // 3. Emplacement (StarterPlayer, StarterGui → LocalScript par défaut)
    if (dirPath.includes('starterplayer') || dirPath.includes('startergui')) {
        // Sauf si c'est clairement un module (commence par return sur la première ligne non-commentaire)
        if (content) {
            // Ignorer les commentaires au début
            const lines = content.split('\n');
            for (const line of lines) {
                const trimmed = line.trim();
                // Ignorer les lignes vides et commentaires
                if (trimmed === '' || trimmed.startsWith('--')) continue;
                // Si la première ligne de code est "return", c'est un module
                if (trimmed.startsWith('return ') || trimmed.startsWith('return{')) {
                    return 'ModuleScript';
                }
                // Sinon, c'est un LocalScript
                break;
            }
        }
        return 'LocalScript';
    }
    
    // 4. Contenu (commence par return ou pattern module)
    if (content) {
        const trimmed = content.trimStart();
        // Pattern module classique: return {} ou return function
        if (trimmed.startsWith('return ') || trimmed.startsWith('return{')) {
            return 'ModuleScript';
        }
        // Pattern: local Module = {} ... return Module
        if (content.match(/^local\s+\w+\s*=\s*\{\}/m) && content.match(/\nreturn\s+\w+\s*$/)) {
            return 'ModuleScript';
        }
    }
    
    // 5. Par défaut: Script (serveur)
    return 'Script';
}

// Calculer le hash MD5 d'un contenu
function computeHash(content) {
    return crypto.createHash('md5').update(content || '').digest('hex');
}

// Récupérer tous les scripts globaux avec leurs hash
function getGlobalScriptsWithHashes() {
    const scripts = {};
    const serviceDirs = ['ServerScriptService', 'ReplicatedStorage', 'StarterPlayer', 'StarterGui'];
    
    function collectScripts(dir, relativePath = '') {
        if (!fs.existsSync(dir)) return;
        
        const items = fs.readdirSync(dir);
        for (const item of items) {
            const fullPath = path.join(dir, item);
            const itemRelPath = relativePath ? relativePath + '/' + item : item;
            
            try {
                const stats = fs.statSync(fullPath);
                if (stats.isDirectory()) {
                    collectScripts(fullPath, itemRelPath);
                } else if (item.endsWith('.lua')) {
                    const content = fs.readFileSync(fullPath, 'utf8');
                    scripts[itemRelPath] = {
                        hash: computeHash(content),
                        content: content,
                        lastModified: stats.mtime.getTime()
                    };
                }
            } catch (e) {
                console.error(`Erreur lecture ${fullPath}:`, e.message);
            }
        }
    }
    
    for (const serviceDir of serviceDirs) {
        collectScripts(path.join(ROOT_DIR, serviceDir), serviceDir);
    }
    
    return scripts;
}

// Charger les hash sauvegardés pour une scène
function loadSceneScriptHashes(sceneName) {
    const hashFile = path.join(ROOT_DIR, 'Scenes', `${sceneName}_ScriptHashes.json`);
    if (fs.existsSync(hashFile)) {
        try {
            return JSON.parse(fs.readFileSync(hashFile, 'utf8'));
        } catch (e) {
            return {};
        }
    }
    return {};
}

// Sauvegarder les hash pour une scène
function saveSceneScriptHashes(sceneName, hashes) {
    const hashFile = path.join(ROOT_DIR, 'Scenes', `${sceneName}_ScriptHashes.json`);
    fs.writeFileSync(hashFile, JSON.stringify(hashes, null, 2));
}

// --------------------------------------------------------
// ROUTES API - Dossiers Partagés
// --------------------------------------------------------

// Récupérer la configuration des dossiers partagés
app.get('/shared-folders/config', (req, res) => {
    const config = loadSharedFoldersConfig();
    res.json(config);
});

// Sauvegarder la configuration des dossiers partagés
app.post('/shared-folders/config', (req, res) => {
    const config = req.body;
    
    if (!config) {
        return res.status(400).json({ error: "Configuration requise" });
    }
    
    if (saveSharedFoldersConfig(config)) {
        console.log('📁 Configuration des dossiers partagés mise à jour');
        res.json({ success: true });
    } else {
        res.status(500).json({ error: "Erreur sauvegarde configuration" });
    }
});

// Ajouter un dossier partagé
app.post('/shared-folders/add', (req, res) => {
    const { name, path: folderPath, target, description } = req.body;
    
    if (!name || !folderPath || !target) {
        return res.status(400).json({ error: "name, path et target requis" });
    }
    
    const config = loadSharedFoldersConfig();
    
    // Vérifier si le nom existe déjà
    if (config.shared_folders.some(f => f.name === name)) {
        return res.status(400).json({ error: `Un dossier partagé nommé '${name}' existe déjà` });
    }
    
    // Vérifier si le chemin existe
    const resolvedPath = resolveSharedPath(folderPath);
    if (!fs.existsSync(resolvedPath)) {
        // Créer le dossier s'il n'existe pas
        try {
            fs.mkdirSync(resolvedPath, { recursive: true });
            console.log(`📁 Dossier créé: ${resolvedPath}`);
        } catch (e) {
            return res.status(400).json({ error: `Impossible de créer le dossier: ${e.message}` });
        }
    }
    
    config.shared_folders.push({
        name: name,
        path: folderPath,
        target: target,
        enabled: true,
        description: description || ''
    });
    
    if (saveSharedFoldersConfig(config)) {
        console.log(`📁 Dossier partagé ajouté: ${name} -> ${target}`);
        res.json({ success: true, folder: config.shared_folders[config.shared_folders.length - 1] });
    } else {
        res.status(500).json({ error: "Erreur sauvegarde configuration" });
    }
});

// Supprimer un dossier partagé
app.delete('/shared-folders/:name', (req, res) => {
    const folderName = req.params.name;
    const config = loadSharedFoldersConfig();
    
    const index = config.shared_folders.findIndex(f => f.name === folderName);
    if (index === -1) {
        return res.status(404).json({ error: `Dossier partagé '${folderName}' introuvable` });
    }
    
    config.shared_folders.splice(index, 1);
    
    if (saveSharedFoldersConfig(config)) {
        console.log(`🗑️ Dossier partagé supprimé: ${folderName}`);
        res.json({ success: true });
    } else {
        res.status(500).json({ error: "Erreur sauvegarde configuration" });
    }
});

// Activer/Désactiver un dossier partagé
app.post('/shared-folders/:name/toggle', (req, res) => {
    const folderName = req.params.name;
    const { enabled } = req.body;
    const config = loadSharedFoldersConfig();
    
    const folder = config.shared_folders.find(f => f.name === folderName);
    if (!folder) {
        return res.status(404).json({ error: `Dossier partagé '${folderName}' introuvable` });
    }
    
    folder.enabled = enabled !== undefined ? enabled : !folder.enabled;
    
    if (saveSharedFoldersConfig(config)) {
        console.log(`📁 Dossier partagé ${folder.enabled ? 'activé' : 'désactivé'}: ${folderName}`);
        res.json({ success: true, enabled: folder.enabled });
    } else {
        res.status(500).json({ error: "Erreur sauvegarde configuration" });
    }
});

// Récupérer les scripts de tous les dossiers partagés activés
app.get('/shared-folders/scripts', (req, res) => {
    const scripts = getAllSharedScripts();
    console.log(`📁 ${scripts.length} scripts récupérés depuis les dossiers partagés`);
    res.json({ scripts: scripts });
});

// Récupérer les scripts d'un dossier partagé spécifique
app.get('/shared-folders/:name/scripts', (req, res) => {
    const folderName = req.params.name;
    const config = loadSharedFoldersConfig();
    
    const folder = config.shared_folders.find(f => f.name === folderName);
    if (!folder) {
        return res.status(404).json({ error: `Dossier partagé '${folderName}' introuvable` });
    }
    
    const scripts = collectSharedScripts(folder);
    console.log(`📁 ${scripts.length} scripts récupérés depuis ${folderName}`);
    res.json({ scripts: scripts, folder: folder });
});

// Vérifier l'état de synchronisation des dossiers partagés
app.get('/shared-folders/status', (req, res) => {
    const config = loadSharedFoldersConfig();
    const status = [];
    
    for (const folder of config.shared_folders || []) {
        const resolvedPath = resolveSharedPath(folder.path);
        const exists = fs.existsSync(resolvedPath);
        let scriptCount = 0;
        
        if (exists && folder.enabled) {
            const scripts = collectSharedScripts(folder);
            scriptCount = scripts.length;
        }
        
        status.push({
            name: folder.name,
            path: folder.path,
            resolvedPath: resolvedPath,
            target: folder.target,
            enabled: folder.enabled,
            exists: exists,
            scriptCount: scriptCount,
            description: folder.description
        });
    }
    
    res.json({ 
        folders: status,
        settings: config.settings || {}
    });
});

// Synchroniser un script depuis un dossier partagé vers le projet
app.post('/shared-folders/sync-script', (req, res) => {
    const { sharedFolderName, relativePath, content } = req.body;
    
    if (!sharedFolderName || !relativePath) {
        return res.status(400).json({ error: "sharedFolderName et relativePath requis" });
    }
    
    const config = loadSharedFoldersConfig();
    const folder = config.shared_folders.find(f => f.name === sharedFolderName);
    
    if (!folder) {
        return res.status(404).json({ error: `Dossier partagé '${sharedFolderName}' introuvable` });
    }
    
    // Écrire le script dans le dossier partagé
    const sourcePath = resolveSharedPath(folder.path);
    const fullPath = path.join(sourcePath, relativePath);
    const folderPath = path.dirname(fullPath);
    
    try {
        if (!fs.existsSync(folderPath)) {
            fs.mkdirSync(folderPath, { recursive: true });
        }
        
        fs.writeFileSync(fullPath, content);
        console.log(`📝 Script synchronisé vers dossier partagé: ${relativePath}`);
        
        res.json({ 
            success: true, 
            path: fullPath,
            hash: computeHash(content)
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Créer le dossier shared_code s'il n'existe pas
const SHARED_CODE_DIR = path.join(path.dirname(ROOT_DIR), 'shared_code');
if (!fs.existsSync(SHARED_CODE_DIR)) {
    fs.mkdirSync(SHARED_CODE_DIR, { recursive: true });
    fs.mkdirSync(path.join(SHARED_CODE_DIR, 'Modules'), { recursive: true });
    fs.mkdirSync(path.join(SHARED_CODE_DIR, 'Events'), { recursive: true });
    console.log('📁 Dossier shared_code créé avec sous-dossiers');
}

// --------------------------------------------------------
// 1. GESTION DES SCÈNES (WORKSPACE / MAP) - JSON
// --------------------------------------------------------

// Stockage temporaire pour les chunks
const chunkStorage = {};

app.post('/save-scene-chunk', (req, res) => {
    const { sceneName, chunkIndex, totalChunks, data, scripts, scriptChunkIndex, totalScriptChunks } = req.body;
    
    if (!chunkStorage[sceneName]) {
        chunkStorage[sceneName] = { 
            chunks: [], 
            totalChunks, 
            scripts: [], 
            receivedChunks: 0,
            receivedScriptChunks: 0,
            totalScriptChunks: 0
        };
    }
    
    // Chunks négatifs = scripts uniquement (envoyés séparément en plusieurs morceaux)
    if (chunkIndex < 0) {
        if (scripts && scripts.length > 0) {
            // Ajouter les scripts de ce chunk à la liste
            chunkStorage[sceneName].scripts.push(...scripts);
            chunkStorage[sceneName].receivedScriptChunks++;
            chunkStorage[sceneName].totalScriptChunks = totalScriptChunks || 1;
            console.log(`📜 Scripts chunk ${(scriptChunkIndex || 0) + 1}/${totalScriptChunks || 1} reçu (${scripts.length} scripts) pour ${sceneName}`);
        }
        res.json({ success: true, complete: false });
        return;
    }
    
    chunkStorage[sceneName].chunks[chunkIndex] = data;
    chunkStorage[sceneName].receivedChunks++;
    
    // Les scripts peuvent aussi être envoyés avec un chunk (ancien comportement)
    if (scripts && scripts.length > 0) {
        chunkStorage[sceneName].scripts.push(...scripts);
        console.log(`📜 ${scripts.length} scripts reçus avec chunk pour ${sceneName}`);
    }
    
    console.log(`📦 Chunk ${chunkIndex + 1}/${totalChunks} reçu pour ${sceneName}`);
    
    // Vérifier si tous les chunks sont reçus
    const allReceived = chunkStorage[sceneName].receivedChunks === totalChunks;
    
    if (allReceived) {
        try {
            // Reconstituer les données complètes
            const fullData = chunkStorage[sceneName].chunks.flat();
            const savedScripts = chunkStorage[sceneName].scripts || [];
            
            // Nouveau format avec objets ET scripts
            const sceneData = {
                objects: fullData,
                scripts: savedScripts
            };
            
            const filePath = path.join(ROOT_DIR, 'Scenes', `${sceneName}.json`);
            fs.writeFileSync(filePath, JSON.stringify(sceneData, null, 2));
            console.log(`💾 Scène sauvegardée : ${sceneName} (${fullData.length} objets, ${savedScripts.length} scripts)`);
            
            // Nettoyer le stockage temporaire
            delete chunkStorage[sceneName];
            
            res.json({ success: true, complete: true });
        } catch (e) {
            res.status(500).json({ error: e.message });
        }
    } else {
        res.json({ success: true, complete: false });
    }
});

app.post('/save-scene', (req, res) => {
    const sceneName = req.query.name || "Scene";
    const filePath = path.join(ROOT_DIR, 'Scenes', `${sceneName}.json`);
    try {
        // Le body peut être un array (ancien format) ou un objet avec objects et scripts
        const data = req.body;
        let objectCount = 0;
        let scriptCount = 0;
        
        if (Array.isArray(data)) {
            // Ancien format : juste les objets
            objectCount = data.length;
        } else {
            // Nouveau format : { objects: [...], scripts: [...] }
            objectCount = data.objects ? data.objects.length : 0;
            scriptCount = data.scripts ? data.scripts.length : 0;
        }
        
        fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
        console.log(`💾 Scène sauvegardée : ${sceneName} (${objectCount} objets, ${scriptCount} scripts)`);
        res.json({ success: true, objects: objectCount, scripts: scriptCount });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/load-scene', (req, res) => {
    const sceneName = req.query.name;
    const chunkIndex = req.query.chunk !== undefined ? parseInt(req.query.chunk) : null;
    const filePath = path.join(ROOT_DIR, 'Scenes', `${sceneName}.json`);
    
    if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: "Introuvable" });
    }
    
    const rawData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    
    // Supporter ancien et nouveau format
    let objects, scripts;
    if (Array.isArray(rawData)) {
        // Ancien format : juste les objets
        objects = rawData;
        scripts = [];
    } else {
        // Nouveau format : { objects: [...], scripts: [...] }
        objects = rawData.objects || [];
        scripts = rawData.scripts || [];
    }
    
    // Si pas de chunk demandé, envoyer juste les métadonnées
    if (chunkIndex === null) {
        console.log(`📊 Métadonnées Scène : ${sceneName} (${objects.length} objets, ${scripts.length} scripts)`);
        return res.json({
            totalObjects: objects.length,
            totalScripts: scripts.length,
            chunkSize: 200,
            totalChunks: Math.ceil(objects.length / 200),
            scripts: scripts // Envoyer les scripts avec les métadonnées
        });
    }
    
    // Envoyer le chunk demandé
    const CHUNK_SIZE = 200;
    const startIdx = chunkIndex * CHUNK_SIZE;
    const endIdx = Math.min((chunkIndex + 1) * CHUNK_SIZE, objects.length);
    const chunk = objects.slice(startIdx, endIdx);
    
    console.log(`📦 Chunk ${chunkIndex + 1}/${Math.ceil(objects.length / CHUNK_SIZE)} envoyé pour ${sceneName}`);
    
    res.json({
        chunkIndex: chunkIndex,
        totalChunks: Math.ceil(objects.length / CHUNK_SIZE),
        data: chunk
    });
});

app.get('/list-scenes', (req, res) => {
    try {
        const scenesDir = path.join(ROOT_DIR, 'Scenes');
        if (!fs.existsSync(scenesDir)) return res.json([]);
        const files = fs.readdirSync(scenesDir).filter(f => f.endsWith('.json')).map(f => f.replace('.json', ''));
        res.json(files);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// Supprimer une scène
app.delete('/delete-scene', (req, res) => {
    const sceneName = req.query.name;
    if (!sceneName) return res.status(400).json({ error: "Nom de scène requis" });
    
    const filePath = path.join(ROOT_DIR, 'Scenes', `${sceneName}.json`);
    
    if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: `Scène '${sceneName}' introuvable` });
    }
    
    try {
        fs.unlinkSync(filePath);
        console.log(`🗑️ Scène supprimée: ${sceneName}`);
        res.json({ success: true, message: `Scène '${sceneName}' supprimée` });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Dupliquer une scène
app.post('/duplicate-scene', (req, res) => {
    const { sourceName, newName } = req.body;
    
    if (!sourceName || !newName) {
        return res.status(400).json({ error: "sourceName et newName requis" });
    }
    
    const sourceFile = path.join(ROOT_DIR, 'Scenes', `${sourceName}.json`);
    const destFile = path.join(ROOT_DIR, 'Scenes', `${newName}.json`);
    
    if (!fs.existsSync(sourceFile)) {
        return res.status(404).json({ error: `Scène '${sourceName}' introuvable` });
    }
    
    if (fs.existsSync(destFile)) {
        return res.status(400).json({ error: `Scène '${newName}' existe déjà` });
    }
    
    try {
        fs.copyFileSync(sourceFile, destFile);
        console.log(`📋 Scène dupliquée: ${sourceName} → ${newName}`);
        res.json({ success: true, newScene: newName });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// --------------------------------------------------------
// SCRIPT CONFLICT DETECTION - Système style Unity/Unreal
// --------------------------------------------------------

// Comparer les scripts entre deux scènes et détecter les conflits
app.get('/compare-scripts', (req, res) => {
    const scene1Name = req.query.scene1;
    const scene2Name = req.query.scene2;
    
    if (!scene1Name || !scene2Name) {
        return res.status(400).json({ error: "scene1 et scene2 requis" });
    }
    
    const file1 = path.join(ROOT_DIR, 'Scenes', `${scene1Name}.json`);
    const file2 = path.join(ROOT_DIR, 'Scenes', `${scene2Name}.json`);
    
    // Aussi vérifier les dossiers _Scripts
    const scriptsDir1 = path.join(ROOT_DIR, 'Scenes', `${scene1Name}_Scripts`);
    const scriptsDir2 = path.join(ROOT_DIR, 'Scenes', `${scene2Name}_Scripts`);
    
    // Collecter les scripts de la scène 1
    let scripts1 = [];
    if (fs.existsSync(file1)) {
        const rawData = JSON.parse(fs.readFileSync(file1, 'utf8'));
        scripts1 = Array.isArray(rawData) ? [] : (rawData.scripts || []);
    }
    
    // Collecter les scripts de la scène 2
    let scripts2 = [];
    if (fs.existsSync(file2)) {
        const rawData = JSON.parse(fs.readFileSync(file2, 'utf8'));
        scripts2 = Array.isArray(rawData) ? [] : (rawData.scripts || []);
    }
    
    // Aussi collecter depuis les dossiers _Scripts si vides
    function collectFromDisk(dir) {
        const scripts = [];
        if (!fs.existsSync(dir)) return scripts;
        
        function walk(currentDir, relativePath = '') {
            const items = fs.readdirSync(currentDir);
            for (const item of items) {
                const fullPath = path.join(currentDir, item);
                const itemRelPath = relativePath ? relativePath + '/' + item : item;
                const stats = fs.statSync(fullPath);
                
                if (stats.isDirectory()) {
                    walk(fullPath, itemRelPath);
                } else if (item.endsWith('.lua')) {
                    const content = fs.readFileSync(fullPath, 'utf8');
                    scripts.push({ path: itemRelPath, source: content });
                }
            }
        }
        walk(dir);
        return scripts;
    }
    
    if (scripts1.length === 0) scripts1 = collectFromDisk(scriptsDir1);
    if (scripts2.length === 0) scripts2 = collectFromDisk(scriptsDir2);
    
    // Créer des maps par chemin
    const map1 = {};
    const map2 = {};
    
    scripts1.forEach(s => { map1[s.path] = s.source || s.content || ''; });
    scripts2.forEach(s => { map2[s.path] = s.source || s.content || ''; });
    
    const result = {
        onlyInScene1: [],      // Scripts uniquement dans scene1
        onlyInScene2: [],      // Scripts uniquement dans scene2
        conflicts: [],         // Scripts avec même chemin mais contenu différent
        identical: [],         // Scripts identiques
        summary: {}
    };
    
    // Comparer
    for (const scriptPath in map1) {
        if (!map2[scriptPath]) {
            result.onlyInScene1.push(scriptPath);
        } else {
            // Comparer le contenu
            const content1 = map1[scriptPath];
            const content2 = map2[scriptPath];
            
            if (content1 !== content2) {
                // Trouver les différences ligne par ligne
                const lines1 = content1.split('\n');
                const lines2 = content2.split('\n');
                const diffs = [];
                
                const maxLines = Math.max(lines1.length, lines2.length);
                for (let i = 0; i < Math.min(maxLines, 20); i++) { // Limiter à 20 lignes de diff
                    if (lines1[i] !== lines2[i]) {
                        diffs.push({
                            line: i + 1,
                            scene1: lines1[i] || '(vide)',
                            scene2: lines2[i] || '(vide)'
                        });
                    }
                }
                
                result.conflicts.push({
                    path: scriptPath,
                    linesScene1: lines1.length,
                    linesScene2: lines2.length,
                    diffCount: diffs.length,
                    diffs: diffs.slice(0, 5) // Limiter à 5 exemples de diff
                });
            } else {
                result.identical.push(scriptPath);
            }
        }
    }
    
    // Scripts uniquement dans scene2
    for (const scriptPath in map2) {
        if (!map1[scriptPath]) {
            result.onlyInScene2.push(scriptPath);
        }
    }
    
    result.summary = {
        scene1Total: scripts1.length,
        scene2Total: scripts2.length,
        onlyInScene1: result.onlyInScene1.length,
        onlyInScene2: result.onlyInScene2.length,
        conflicts: result.conflicts.length,
        identical: result.identical.length
    };
    
    console.log(`📜 Comparaison scripts ${scene1Name} vs ${scene2Name}:`);
    console.log(`   - Uniquement dans ${scene1Name}: ${result.onlyInScene1.length}`);
    console.log(`   - Uniquement dans ${scene2Name}: ${result.onlyInScene2.length}`);
    console.log(`   - Conflits: ${result.conflicts.length}`);
    console.log(`   - Identiques: ${result.identical.length}`);
    
    res.json(result);
});

// Comparer les scripts de TOUTES les scènes pour détecter les conflits globaux
app.get('/detect-all-script-conflicts', (req, res) => {
    const scenesDir = path.join(ROOT_DIR, 'Scenes');
    if (!fs.existsSync(scenesDir)) return res.json({ conflicts: [], scenes: [] });
    
    // Lister toutes les scènes
    const sceneFiles = fs.readdirSync(scenesDir).filter(f => f.endsWith('.json'));
    const scenes = sceneFiles.map(f => f.replace('.json', ''));
    
    // Collecter tous les scripts de toutes les scènes
    const allScripts = {}; // { scriptPath: { sceneName: content, ... } }
    
    for (const sceneName of scenes) {
        const filePath = path.join(scenesDir, `${sceneName}.json`);
        const scriptsDir = path.join(scenesDir, `${sceneName}_Scripts`);
        
        let scripts = [];
        
        // Depuis le JSON
        if (fs.existsSync(filePath)) {
            const rawData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
            scripts = Array.isArray(rawData) ? [] : (rawData.scripts || []);
        }
        
        // Depuis le dossier _Scripts si vide
        if (scripts.length === 0 && fs.existsSync(scriptsDir)) {
            function walk(dir, relativePath = '') {
                const items = fs.readdirSync(dir);
                for (const item of items) {
                    const fullPath = path.join(dir, item);
                    const itemRelPath = relativePath ? relativePath + '/' + item : item;
                    const stats = fs.statSync(fullPath);
                    
                    if (stats.isDirectory()) {
                        walk(fullPath, itemRelPath);
                    } else if (item.endsWith('.lua')) {
                        const content = fs.readFileSync(fullPath, 'utf8');
                        scripts.push({ path: itemRelPath, source: content });
                    }
                }
            }
            walk(scriptsDir);
        }
        
        // Ajouter au dictionnaire global
        for (const script of scripts) {
            const scriptPath = script.path;
            const content = script.source || script.content || '';
            
            if (!allScripts[scriptPath]) {
                allScripts[scriptPath] = {};
            }
            allScripts[scriptPath][sceneName] = content;
        }
    }
    
    // Détecter les conflits (scripts présents dans plusieurs scènes avec contenu différent)
    const conflicts = [];
    
    for (const scriptPath in allScripts) {
        const sceneContents = allScripts[scriptPath];
        const sceneNames = Object.keys(sceneContents);
        
        if (sceneNames.length > 1) {
            // Script présent dans plusieurs scènes, vérifier si contenu différent
            const contents = Object.values(sceneContents);
            const uniqueContents = [...new Set(contents)];
            
            if (uniqueContents.length > 1) {
                // Conflit détecté !
                conflicts.push({
                    scriptPath: scriptPath,
                    scenes: sceneNames,
                    versions: uniqueContents.length,
                    details: sceneNames.map(name => ({
                        scene: name,
                        lines: sceneContents[name].split('\n').length,
                        preview: sceneContents[name].substring(0, 100) + '...'
                    }))
                });
            }
        }
    }
    
    console.log(`🔍 Analyse globale: ${conflicts.length} conflits de scripts détectés sur ${scenes.length} scènes`);
    
    res.json({
        scenes: scenes,
        totalScripts: Object.keys(allScripts).length,
        conflicts: conflicts
    });
});

// --------------------------------------------------------
// MERGE SYSTEM - Comparaison et fusion de scènes
// --------------------------------------------------------

// Comparer deux scènes et détecter les conflits
app.get('/compare-scenes', (req, res) => {
    const scene1Name = req.query.scene1;
    const scene2Name = req.query.scene2;
    
    const file1 = path.join(ROOT_DIR, 'Scenes', `${scene1Name}.json`);
    const file2 = path.join(ROOT_DIR, 'Scenes', `${scene2Name}.json`);
    
    if (!fs.existsSync(file1)) return res.status(404).json({ error: `Scène '${scene1Name}' introuvable` });
    if (!fs.existsSync(file2)) return res.status(404).json({ error: `Scène '${scene2Name}' introuvable` });
    
    const rawData1 = JSON.parse(fs.readFileSync(file1, 'utf8'));
    const rawData2 = JSON.parse(fs.readFileSync(file2, 'utf8'));
    
    // Supporter l'ancien format (array) et le nouveau format ({ objects: [...], scripts: [...] })
    const data1 = Array.isArray(rawData1) ? rawData1 : (rawData1.objects || []);
    const data2 = Array.isArray(rawData2) ? rawData2 : (rawData2.objects || []);
    
    // Créer des maps par ID pour comparaison rapide
    const map1 = {};
    const map2 = {};
    
    data1.forEach(obj => { map1[obj.ID] = obj; });
    data2.forEach(obj => { map2[obj.ID] = obj; });
    
    const result = {
        onlyInScene1: [], // Objets uniquement dans scene1
        onlyInScene2: [], // Objets uniquement dans scene2
        conflicts: [],    // Objets avec même ID mais propriétés différentes
        identical: 0      // Nombre d'objets identiques
    };
    
    // Trouver les objets uniquement dans scene1 et les conflits
    for (const id in map1) {
        if (!map2[id]) {
            result.onlyInScene1.push({ id, name: map1[id].Name, className: map1[id].ClassName });
        } else {
            // Comparer les propriétés
            const obj1 = map1[id];
            const obj2 = map2[id];
            const props1 = JSON.stringify(obj1.Properties);
            const props2 = JSON.stringify(obj2.Properties);
            
            if (props1 !== props2) {
                result.conflicts.push({
                    id,
                    name: obj1.Name,
                    className: obj1.ClassName,
                    scene1Props: obj1.Properties,
                    scene2Props: obj2.Properties
                });
            } else {
                result.identical++;
            }
        }
    }
    
    // Trouver les objets uniquement dans scene2
    for (const id in map2) {
        if (!map1[id]) {
            result.onlyInScene2.push({ id, name: map2[id].Name, className: map2[id].ClassName });
        }
    }
    
    console.log(`🔀 Comparaison ${scene1Name} vs ${scene2Name}:`);
    console.log(`   - Uniquement dans ${scene1Name}: ${result.onlyInScene1.length}`);
    console.log(`   - Uniquement dans ${scene2Name}: ${result.onlyInScene2.length}`);
    console.log(`   - Conflits: ${result.conflicts.length}`);
    console.log(`   - Identiques: ${result.identical}`);
    
    res.json(result);
});

// Merger deux scènes
app.post('/merge-scenes', (req, res) => {
    const { baseScene, mergeScene, conflictResolutions, outputScene } = req.body;
    // conflictResolutions: { [id]: "base" | "merge" | "both" }
    
    const baseFile = path.join(ROOT_DIR, 'Scenes', `${baseScene}.json`);
    const mergeFile = path.join(ROOT_DIR, 'Scenes', `${mergeScene}.json`);
    
    if (!fs.existsSync(baseFile)) return res.status(404).json({ error: `Scène '${baseScene}' introuvable` });
    if (!fs.existsSync(mergeFile)) return res.status(404).json({ error: `Scène '${mergeScene}' introuvable` });
    
    const rawBaseData = JSON.parse(fs.readFileSync(baseFile, 'utf8'));
    const rawMergeData = JSON.parse(fs.readFileSync(mergeFile, 'utf8'));
    
    // Supporter l'ancien format (array) et le nouveau format ({ objects: [...], scripts: [...] })
    const baseData = Array.isArray(rawBaseData) ? rawBaseData : (rawBaseData.objects || []);
    const mergeData = Array.isArray(rawMergeData) ? rawMergeData : (rawMergeData.objects || []);
    let baseScripts = Array.isArray(rawBaseData) ? [] : (rawBaseData.scripts || []);
    let mergeScripts = Array.isArray(rawMergeData) ? [] : (rawMergeData.scripts || []);
    
    // Fonction pour collecter les scripts depuis un dossier _Scripts
    function collectScriptsFromDisk(sceneName) {
        const scriptsDir = path.join(ROOT_DIR, 'Scenes', `${sceneName}_Scripts`);
        const scripts = [];
        
        if (!fs.existsSync(scriptsDir)) return scripts;
        
        function walk(dir, relativePath = '') {
            const items = fs.readdirSync(dir);
            for (const item of items) {
                const fullPath = path.join(dir, item);
                const itemRelPath = relativePath ? relativePath + '/' + item : item;
                const stats = fs.statSync(fullPath);
                
                if (stats.isDirectory()) {
                    walk(fullPath, itemRelPath);
                } else if (item.endsWith('.lua')) {
                    const content = fs.readFileSync(fullPath, 'utf8');
                    const className = detectScriptType(itemRelPath, content);
                    scripts.push({
                        path: itemRelPath,
                        className: className,
                        source: content,
                        disabled: false
                    });
                }
            }
        }
        walk(scriptsDir);
        return scripts;
    }
    
    // Si pas de scripts dans le JSON, essayer de les récupérer depuis le dossier _Scripts
    if (baseScripts.length === 0) {
        baseScripts = collectScriptsFromDisk(baseScene);
        if (baseScripts.length > 0) {
            console.log(`📜 ${baseScripts.length} scripts récupérés depuis ${baseScene}_Scripts`);
        }
    }
    if (mergeScripts.length === 0) {
        mergeScripts = collectScriptsFromDisk(mergeScene);
        if (mergeScripts.length > 0) {
            console.log(`📜 ${mergeScripts.length} scripts récupérés depuis ${mergeScene}_Scripts`);
        }
    }
    
    // Créer des maps
    const baseMap = {};
    const mergeMap = {};
    
    baseData.forEach(obj => { baseMap[obj.ID] = obj; });
    mergeData.forEach(obj => { mergeMap[obj.ID] = obj; });
    
    const result = [];
    const addedIds = new Set();
    
    // Ajouter tous les objets de base
    for (const obj of baseData) {
        const id = obj.ID;
        
        if (mergeMap[id]) {
            // Conflit potentiel
            const resolution = conflictResolutions?.[id] || "base";
            
            if (resolution === "merge") {
                result.push(mergeMap[id]);
            } else if (resolution === "both") {
                // Garder les deux avec des IDs différents
                result.push(obj);
                const clonedObj = JSON.parse(JSON.stringify(mergeMap[id]));
                clonedObj.ID = clonedObj.ID + "_merged";
                clonedObj.Name = clonedObj.Name + "_merged";
                result.push(clonedObj);
            } else {
                // Par défaut: garder base
                result.push(obj);
            }
        } else {
            result.push(obj);
        }
        addedIds.add(id);
    }
    
    // Ajouter les objets uniquement dans merge
    for (const obj of mergeData) {
        if (!addedIds.has(obj.ID)) {
            result.push(obj);
        }
    }
    
    // Merger les scripts (prendre tous les scripts uniques des deux scènes)
    const scriptMap = {};
    for (const script of baseScripts) {
        scriptMap[script.path] = script;
    }
    for (const script of mergeScripts) {
        // Les scripts de merge écrasent ceux de base si même chemin
        scriptMap[script.path] = script;
    }
    const mergedScripts = Object.values(scriptMap);
    
    // Sauvegarder le résultat avec le nouveau format
    const outputName = outputScene || `${baseScene}_merged`;
    const outputFile = path.join(ROOT_DIR, 'Scenes', `${outputName}.json`);
    const outputData = {
        objects: result,
        scripts: mergedScripts
    };
    fs.writeFileSync(outputFile, JSON.stringify(outputData, null, 2));
    
    // Aussi sauvegarder les scripts dans le dossier _Scripts de la scène de sortie
    if (mergedScripts.length > 0) {
        const outputScriptsDir = path.join(ROOT_DIR, 'Scenes', `${outputName}_Scripts`);
        
        // Créer le dossier s'il n'existe pas
        if (!fs.existsSync(outputScriptsDir)) {
            fs.mkdirSync(outputScriptsDir, { recursive: true });
        }
        
        for (const script of mergedScripts) {
            const scriptPath = path.join(outputScriptsDir, script.path);
            const folderPath = path.dirname(scriptPath);
            
            if (!fs.existsSync(folderPath)) {
                fs.mkdirSync(folderPath, { recursive: true });
            }
            
            const content = script.source || script.content || '';
            fs.writeFileSync(scriptPath, content);
        }
        console.log(`📁 Scripts copiés dans ${outputName}_Scripts`);
    }
    
    console.log(`✅ Merge terminé: ${outputName} (${result.length} objets, ${mergedScripts.length} scripts)`);
    
    res.json({ 
        success: true, 
        outputScene: outputName,
        totalObjects: result.length,
        totalScripts: mergedScripts.length
    });
});

// --------------------------------------------------------
// 2. GESTION DES SCRIPTS GLOBAUX - Système de versioning
// --------------------------------------------------------

// Récupérer l'état actuel des scripts globaux (pour le LOAD)
app.get('/get-global-scripts', (req, res) => {
    const scripts = getGlobalScriptsWithHashes();
    const scriptList = [];
    
    for (const [scriptPath, data] of Object.entries(scripts)) {
        const className = detectScriptType(scriptPath, data.content);
        
        scriptList.push({
            path: scriptPath,
            className: className,
            source: data.content,
            hash: data.hash
        });
    }
    
    console.log(`📜 ${scriptList.length} scripts globaux récupérés`);
    res.json({ scripts: scriptList });
});

// Récupérer uniquement les hash des scripts globaux (pour vérification rapide)
app.get('/get-global-script-hashes', (req, res) => {
    const scripts = getGlobalScriptsWithHashes();
    const hashes = {};
    
    for (const [scriptPath, data] of Object.entries(scripts)) {
        hashes[scriptPath] = data.hash;
    }
    
    res.json({ hashes });
});

// Sauvegarder les scripts globaux et enregistrer les hash pour une scène
app.post('/save-global-scripts', (req, res) => {
    const { sceneName, scripts } = req.body;
    
    if (!sceneName || !scripts) {
        return res.status(400).json({ error: "sceneName et scripts requis" });
    }
    
    const currentGlobalScripts = getGlobalScriptsWithHashes();
    const conflicts = [];
    const savedHashes = {};
    let savedCount = 0;
    let conflictCount = 0;
    
    for (const script of scripts) {
        const scriptPath = script.path;
        const newContent = script.source || script.content || '';
        const newHash = computeHash(newContent);
        
        // Vérifier si le script existe déjà avec un contenu différent
        if (currentGlobalScripts[scriptPath]) {
            const currentHash = currentGlobalScripts[scriptPath].hash;
            
            if (currentHash !== newHash) {
                // Le script a été modifié - vérifier si c'est un conflit
                // (quelqu'un d'autre l'a modifié depuis le dernier load)
                const sceneHashes = loadSceneScriptHashes(sceneName);
                const lastKnownHash = sceneHashes[scriptPath];
                
                if (lastKnownHash && lastKnownHash !== currentHash) {
                    // CONFLIT ! Le script a été modifié par quelqu'un d'autre
                    conflicts.push({
                        path: scriptPath,
                        yourHash: newHash,
                        currentHash: currentHash,
                        lastKnownHash: lastKnownHash,
                        currentContent: currentGlobalScripts[scriptPath].content,
                        yourContent: newContent
                    });
                    conflictCount++;
                    continue; // Ne pas sauvegarder ce script pour l'instant
                }
            }
        }
        
        // Sauvegarder le script
        const fullPath = path.join(ROOT_DIR, scriptPath);
        const folderPath = path.dirname(fullPath);
        
        if (!fs.existsSync(folderPath)) {
            fs.mkdirSync(folderPath, { recursive: true });
        }
        
        fs.writeFileSync(fullPath, newContent);
        savedHashes[scriptPath] = newHash;
        savedCount++;
    }
    
    // Sauvegarder les hash pour cette scène
    saveSceneScriptHashes(sceneName, savedHashes);
    
    console.log(`📜 Scripts sauvegardés pour ${sceneName}: ${savedCount} OK, ${conflictCount} conflits`);
    
    if (conflicts.length > 0) {
        res.json({ 
            success: false, 
            hasConflicts: true,
            conflicts: conflicts,
            savedCount: savedCount
        });
    } else {
        res.json({ 
            success: true, 
            savedCount: savedCount,
            hashes: savedHashes
        });
    }
});

// Forcer la sauvegarde d'un script (résolution de conflit)
app.post('/force-save-script', (req, res) => {
    const { sceneName, scriptPath, content, source, user, machine } = req.body;
    
    if (!scriptPath || content === undefined) {
        return res.status(400).json({ error: "scriptPath et content requis" });
    }
    
    const fullPath = path.join(ROOT_DIR, scriptPath);
    const folderPath = path.dirname(fullPath);
    
    try {
        if (!fs.existsSync(folderPath)) {
            fs.mkdirSync(folderPath, { recursive: true });
        }
        
        fs.writeFileSync(fullPath, content);
        const newHash = computeHash(content);
        
        // Mettre à jour le hash pour la scène
        if (sceneName) {
            const hashes = loadSceneScriptHashes(sceneName);
            hashes[scriptPath] = newHash;
            saveSceneScriptHashes(sceneName, hashes);
        }
        
        // Mettre à jour l'état connu
        lastKnownState[scriptPath] = {
            source: source || 'force',
            timestamp: Date.now(),
            hash: newHash
        };
        
        // Ajouter à l'historique
        const userName = user || machine || 'unknown';
        addHistoryEntry(scriptPath, 'conflict_resolved', userName, {
            source: source || 'manual',
            resolution: source === 'roblox' ? 'kept_roblox' : 'kept_disk',
            machine: machine
        });
        
        console.log(`📜 Script forcé: ${scriptPath}`);
        res.json({ success: true, hash: newHash });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Vérifier les conflits potentiels avant de sauvegarder
app.post('/check-script-conflicts', (req, res) => {
    const { sceneName, scripts } = req.body;
    
    if (!sceneName || !scripts) {
        return res.status(400).json({ error: "sceneName et scripts requis" });
    }
    
    const currentGlobalScripts = getGlobalScriptsWithHashes();
    const sceneHashes = loadSceneScriptHashes(sceneName);
    const conflicts = [];
    const changes = [];
    const newScripts = [];
    
    for (const script of scripts) {
        const scriptPath = script.path;
        const newContent = script.source || script.content || '';
        const newHash = computeHash(newContent);
        
        if (!currentGlobalScripts[scriptPath]) {
            // Nouveau script
            newScripts.push({ path: scriptPath, hash: newHash });
        } else {
            const currentHash = currentGlobalScripts[scriptPath].hash;
            const lastKnownHash = sceneHashes[scriptPath];
            
            if (currentHash !== newHash) {
                if (lastKnownHash && lastKnownHash !== currentHash) {
                    // CONFLIT
                    conflicts.push({
                        path: scriptPath,
                        reason: "Modifié par quelqu'un d'autre depuis ton dernier load",
                        yourHash: newHash,
                        currentHash: currentHash,
                        lastKnownHash: lastKnownHash
                    });
                } else {
                    // Changement normal (tu as modifié le script)
                    changes.push({ path: scriptPath, oldHash: currentHash, newHash: newHash });
                }
            }
        }
    }
    
    res.json({
        hasConflicts: conflicts.length > 0,
        conflicts: conflicts,
        changes: changes,
        newScripts: newScripts
    });
});

// --------------------------------------------------------
// 2b. GESTION DES SCRIPTS (ROJO STYLE) - .lua (legacy)
// --------------------------------------------------------
app.post('/sync-script', (req, res) => {
    // req.body attend : { path: "ServerScriptService/Dossier/Script.lua", content: "print('hi')" }
    const relativePath = req.body.path;
    const content = req.body.content;
    
    const fullPath = path.join(ROOT_DIR, relativePath);
    const folderPath = path.dirname(fullPath);

    try {
        // 1. Créer les dossiers récursivement s'ils n'existent pas
        if (!fs.existsSync(folderPath)) {
            fs.mkdirSync(folderPath, { recursive: true });
        }

        // 2. Écrire le fichier .lua
        fs.writeFileSync(fullPath, content);
        console.log(`📜 Script synchronisé : ${relativePath}`);
        res.json({ success: true });
    } catch (e) {
        console.error("Erreur écriture script:", e);
        res.status(500).json({ error: e.message });
    }
});

// Stockage temporaire pour les chunks de scripts
const scriptChunkStorage = {};

// [DEPRECATED] Route sync-scene-scripts - Redirige vers save-global-scripts
// Les dossiers _Scripts par scène ne sont plus utilisés
app.post('/sync-scene-scripts', (req, res) => {
    console.log('⚠️ sync-scene-scripts est déprécié, utilisez save-global-scripts');
    res.json({ success: true, count: 0, message: "Endpoint déprécié - scripts globaux utilisés" });
});

// Route pour charger les scripts d'une scène (copie du dossier scène vers le dossier principal)
app.post('/load-scene-scripts', (req, res) => {
    const { sceneName } = req.body;
    
    if (!sceneName) {
        return res.status(400).json({ error: "sceneName requis" });
    }
    
    const sceneScriptsDir = path.join(ROOT_DIR, 'Scenes', sceneName + '_Scripts');
    
    // Si le dossier de scripts de la scène n'existe pas, rien à faire
    if (!fs.existsSync(sceneScriptsDir)) {
        console.log(`📜 Pas de dossier scripts pour la scène: ${sceneName}`);
        return res.json({ success: true, count: 0, message: "Pas de scripts spécifiques pour cette scène" });
    }
    
    try {
        let copiedCount = 0;
        
        // Fonction récursive pour copier les fichiers
        function copyScripts(sourceDir, targetBaseDir, relativePath = '') {
            const items = fs.readdirSync(sourceDir);
            
            for (const item of items) {
                const sourcePath = path.join(sourceDir, item);
                const targetPath = path.join(targetBaseDir, relativePath, item);
                const stats = fs.statSync(sourcePath);
                
                if (stats.isDirectory()) {
                    // Créer le dossier cible s'il n'existe pas
                    if (!fs.existsSync(targetPath)) {
                        fs.mkdirSync(targetPath, { recursive: true });
                    }
                    // Récursion
                    copyScripts(sourcePath, targetBaseDir, path.join(relativePath, item));
                } else if (item.endsWith('.lua')) {
                    // Copier le fichier .lua
                    const targetFolder = path.dirname(targetPath);
                    if (!fs.existsSync(targetFolder)) {
                        fs.mkdirSync(targetFolder, { recursive: true });
                    }
                    fs.copyFileSync(sourcePath, targetPath);
                    copiedCount++;
                }
            }
        }
        
        copyScripts(sceneScriptsDir, ROOT_DIR);
        
        console.log(`📜 ${copiedCount} scripts chargés depuis la scène: ${sceneName}`);
        res.json({ success: true, count: copiedCount });
    } catch (e) {
        console.error("Erreur chargement scripts scène:", e);
        res.status(500).json({ error: e.message });
    }
});

// Route pour récupérer tous les scripts d'une scène depuis le dossier _Scripts
// Utilisé quand le JSON ne contient pas de scripts (anciennes sauvegardes)
app.get('/get-scene-scripts-from-disk', (req, res) => {
    const sceneName = req.query.name;
    
    if (!sceneName) {
        return res.status(400).json({ error: "name requis" });
    }
    
    const sceneScriptsDir = path.join(ROOT_DIR, 'Scenes', sceneName + '_Scripts');
    
    if (!fs.existsSync(sceneScriptsDir)) {
        console.log(`📜 Pas de dossier scripts pour: ${sceneName}`);
        return res.json({ scripts: [] });
    }
    
    try {
        const scripts = [];
        
        function collectScripts(dir, relativePath = '') {
            const items = fs.readdirSync(dir);
            
            for (const item of items) {
                const fullPath = path.join(dir, item);
                const itemRelPath = relativePath ? relativePath + '/' + item : item;
                const stats = fs.statSync(fullPath);
                
                if (stats.isDirectory()) {
                    collectScripts(fullPath, itemRelPath);
                } else if (item.endsWith('.lua')) {
                    const content = fs.readFileSync(fullPath, 'utf8');
                    const className = detectScriptType(itemRelPath, content);
                    
                    scripts.push({
                        path: itemRelPath,
                        className: className,
                        source: content,
                        disabled: false
                    });
                }
            }
        }
        
        collectScripts(sceneScriptsDir);
        
        console.log(`📜 ${scripts.length} scripts trouvés sur disque pour: ${sceneName}`);
        res.json({ scripts: scripts });
    } catch (e) {
        console.error("Erreur lecture scripts:", e);
        res.status(500).json({ error: e.message });
    }
});

// Route pour lister tous les scripts du projet (pour Disk → Roblox)
// Inclut maintenant les scripts des dossiers partagés
app.get('/list-all-scripts', (req, res) => {
    const includeShared = req.query.includeShared !== 'false'; // Par défaut: inclure les partagés
    const scripts = [];
    const serviceDirs = ['ServerScriptService', 'ReplicatedStorage', 'StarterPlayer', 'StarterGui'];
    
    function collectScripts(dir, relativePath = '') {
        if (!fs.existsSync(dir)) return;
        
        const items = fs.readdirSync(dir);
        
        for (const item of items) {
            const fullPath = path.join(dir, item);
            const itemRelPath = relativePath ? relativePath + '/' + item : item;
            
            try {
                const stats = fs.statSync(fullPath);
                
                if (stats.isDirectory()) {
                    collectScripts(fullPath, itemRelPath);
                } else if (item.endsWith('.lua')) {
                    const content = fs.readFileSync(fullPath, 'utf8');
                    const className = detectScriptType(itemRelPath, content);
                    
                    scripts.push({
                        path: itemRelPath,
                        className: className,
                        content: content,
                        isShared: false
                    });
                }
            } catch (e) {
                console.error(`Erreur lecture ${fullPath}:`, e.message);
            }
        }
    }
    
    for (const serviceDir of serviceDirs) {
        collectScripts(path.join(ROOT_DIR, serviceDir), serviceDir);
    }
    
    // Ajouter les scripts des dossiers partagés
    let sharedCount = 0;
    if (includeShared) {
        const sharedScripts = getAllSharedScripts();
        for (const script of sharedScripts) {
            // Vérifier si le script n'existe pas déjà (les scripts locaux ont priorité)
            if (!scripts.some(s => s.path === script.path)) {
                scripts.push({
                    path: script.path,
                    className: script.className,
                    content: script.content,
                    isShared: true,
                    sharedFolder: script.sharedFolder
                });
                sharedCount++;
            }
        }
    }
    
    console.log(`📜 ${scripts.length} scripts listés pour sync Disk → Roblox (${sharedCount} partagés)`);
    res.json({ 
        scripts: scripts,
        totalScripts: scripts.length,
        sharedScripts: sharedCount
    });
});

// Route pour récupérer le contenu d'un script (pour hot-reload)
app.get('/get-script', (req, res) => {
    const relativePath = req.query.path;
    const fullPath = path.join(ROOT_DIR, relativePath);
    
    try {
        if (fs.existsSync(fullPath)) {
            const content = fs.readFileSync(fullPath, 'utf8');
            const stats = fs.statSync(fullPath);
            res.json({ 
                success: true, 
                content: content,
                lastModified: stats.mtime.getTime()
            });
        } else {
            res.status(404).json({ error: "Script non trouvé" });
        }
    } catch (e) {
        console.error("Erreur lecture script:", e);
        res.status(500).json({ error: e.message });
    }
});

// --------------------------------------------------------
// SYNC BIDIRECTIONNELLE - Roblox ↔ Disque
// --------------------------------------------------------

// Stockage en mémoire des dernières modifications connues
// Format: { scriptPath: { source: 'roblox' | 'disk', timestamp: number, hash: string } }
const lastKnownState = {};

// --------------------------------------------------------
// HISTORIQUE DES MODIFICATIONS
// --------------------------------------------------------
const HISTORY_FILE = path.join(ROOT_DIR, '.script_history.json');
const MAX_HISTORY_ENTRIES = 500; // Garder les 500 dernières modifications

// Charger l'historique existant
function loadHistory() {
    try {
        if (fs.existsSync(HISTORY_FILE)) {
            return JSON.parse(fs.readFileSync(HISTORY_FILE, 'utf8'));
        }
    } catch (e) {
        console.error('Erreur chargement historique:', e.message);
    }
    return { entries: [], locks: {} };
}

// Sauvegarder l'historique
function saveHistory(history) {
    try {
        // Limiter le nombre d'entrées
        if (history.entries.length > MAX_HISTORY_ENTRIES) {
            history.entries = history.entries.slice(-MAX_HISTORY_ENTRIES);
        }
        fs.writeFileSync(HISTORY_FILE, JSON.stringify(history, null, 2));
    } catch (e) {
        console.error('Erreur sauvegarde historique:', e.message);
    }
}

// Ajouter une entrée à l'historique
function addHistoryEntry(scriptPath, action, user, details = {}) {
    const history = loadHistory();
    const entry = {
        id: Date.now() + '-' + Math.random().toString(36).substr(2, 9),
        timestamp: Date.now(),
        date: new Date().toISOString(),
        scriptPath: scriptPath,
        action: action, // 'modified', 'created', 'deleted', 'locked', 'unlocked', 'conflict_resolved'
        user: user || 'unknown',
        details: details
    };
    
    history.entries.push(entry);
    saveHistory(history);
    
    console.log(`📜 Historique: ${action} ${scriptPath} par ${user}`);
    return entry;
}

// --------------------------------------------------------
// SYSTÈME DE VERROUILLAGE (LOCKS)
// --------------------------------------------------------
// Format: { scriptPath: { user: string, timestamp: number, machine: string } }

// Récupérer tous les locks actifs
function getActiveLocks() {
    const history = loadHistory();
    const locks = history.locks || {};
    
    // Nettoyer les locks expirés (plus de 30 minutes sans activité)
    const LOCK_TIMEOUT = 30 * 60 * 1000; // 30 minutes
    const now = Date.now();
    let cleaned = false;
    
    for (const [path, lock] of Object.entries(locks)) {
        if (now - lock.timestamp > LOCK_TIMEOUT) {
            delete locks[path];
            cleaned = true;
            console.log(`🔓 Lock expiré auto-supprimé: ${path}`);
        }
    }
    
    if (cleaned) {
        history.locks = locks;
        saveHistory(history);
    }
    
    return locks;
}

// Verrouiller un script
function lockScript(scriptPath, user, machine) {
    const history = loadHistory();
    if (!history.locks) history.locks = {};
    
    // Vérifier si déjà verrouillé par quelqu'un d'autre
    const existingLock = history.locks[scriptPath];
    if (existingLock && existingLock.user !== user) {
        return {
            success: false,
            error: 'already_locked',
            lockedBy: existingLock.user,
            lockedAt: existingLock.timestamp,
            machine: existingLock.machine
        };
    }
    
    // Verrouiller
    history.locks[scriptPath] = {
        user: user,
        machine: machine || 'unknown',
        timestamp: Date.now()
    };
    
    saveHistory(history);
    addHistoryEntry(scriptPath, 'locked', user, { machine });
    
    return { success: true };
}

// Déverrouiller un script
function unlockScript(scriptPath, user, force = false) {
    const history = loadHistory();
    if (!history.locks) return { success: true };
    
    const existingLock = history.locks[scriptPath];
    if (!existingLock) {
        return { success: true };
    }
    
    // Vérifier si c'est le bon utilisateur (sauf si force)
    if (!force && existingLock.user !== user) {
        return {
            success: false,
            error: 'not_owner',
            lockedBy: existingLock.user
        };
    }
    
    delete history.locks[scriptPath];
    saveHistory(history);
    addHistoryEntry(scriptPath, 'unlocked', user, { forced: force });
    
    return { success: true };
}

// Rafraîchir le timestamp d'un lock (pour éviter l'expiration)
function refreshLock(scriptPath, user) {
    const history = loadHistory();
    if (!history.locks) return { success: false };
    
    const lock = history.locks[scriptPath];
    if (!lock || lock.user !== user) {
        return { success: false };
    }
    
    lock.timestamp = Date.now();
    saveHistory(history);
    return { success: true };
}

// --------------------------------------------------------
// ROUTES API - Historique
// --------------------------------------------------------

// Récupérer l'historique des modifications
app.get('/history', (req, res) => {
    const limit = parseInt(req.query.limit) || 50;
    const scriptPath = req.query.path;
    const user = req.query.user;
    
    const history = loadHistory();
    let entries = history.entries || [];
    
    // Filtrer par chemin de script
    if (scriptPath) {
        entries = entries.filter(e => e.scriptPath === scriptPath || e.scriptPath.includes(scriptPath));
    }
    
    // Filtrer par utilisateur
    if (user) {
        entries = entries.filter(e => e.user === user);
    }
    
    // Trier par date décroissante et limiter
    entries = entries.sort((a, b) => b.timestamp - a.timestamp).slice(0, limit);
    
    res.json({ entries });
});

// Récupérer l'historique d'un script spécifique
app.get('/history/:scriptPath(*)', (req, res) => {
    const scriptPath = req.params.scriptPath;
    const limit = parseInt(req.query.limit) || 20;
    
    const history = loadHistory();
    let entries = (history.entries || [])
        .filter(e => e.scriptPath === scriptPath)
        .sort((a, b) => b.timestamp - a.timestamp)
        .slice(0, limit);
    
    res.json({ entries });
});

// --------------------------------------------------------
// ROUTES API - Locks
// --------------------------------------------------------

// Récupérer tous les locks actifs
app.get('/locks', (req, res) => {
    const locks = getActiveLocks();
    res.json({ locks });
});

// Verrouiller un script
app.post('/lock', (req, res) => {
    const { scriptPath, user, machine } = req.body;
    
    if (!scriptPath || !user) {
        return res.status(400).json({ error: "scriptPath et user requis" });
    }
    
    const result = lockScript(scriptPath, user, machine);
    res.json(result);
});

// Déverrouiller un script
app.post('/unlock', (req, res) => {
    const { scriptPath, user, force } = req.body;
    
    if (!scriptPath) {
        return res.status(400).json({ error: "scriptPath requis" });
    }
    
    const result = unlockScript(scriptPath, user, force);
    res.json(result);
});

// Rafraîchir un lock (heartbeat)
app.post('/refresh-lock', (req, res) => {
    const { scriptPath, user } = req.body;
    
    if (!scriptPath || !user) {
        return res.status(400).json({ error: "scriptPath et user requis" });
    }
    
    const result = refreshLock(scriptPath, user);
    res.json(result);
});

// --------------------------------------------------------
// DIFF DÉTAILLÉ - Comparaison ligne par ligne
// --------------------------------------------------------

// Calculer le diff entre deux contenus
function computeDiff(content1, content2) {
    const lines1 = content1.split('\n');
    const lines2 = content2.split('\n');
    
    const diff = [];
    const maxLines = Math.max(lines1.length, lines2.length);
    
    // Algorithme simple de diff ligne par ligne
    // Pour un vrai diff, on utiliserait un algorithme LCS (Longest Common Subsequence)
    // mais pour la simplicité, on compare ligne par ligne
    
    let i = 0, j = 0;
    
    while (i < lines1.length || j < lines2.length) {
        const line1 = lines1[i];
        const line2 = lines2[j];
        
        if (i >= lines1.length) {
            // Lignes ajoutées dans content2
            diff.push({
                type: 'added',
                lineNumber: j + 1,
                content: line2,
                side: 'right'
            });
            j++;
        } else if (j >= lines2.length) {
            // Lignes supprimées de content1
            diff.push({
                type: 'removed',
                lineNumber: i + 1,
                content: line1,
                side: 'left'
            });
            i++;
        } else if (line1 === line2) {
            // Lignes identiques
            diff.push({
                type: 'unchanged',
                lineNumber: i + 1,
                content: line1
            });
            i++;
            j++;
        } else {
            // Chercher si la ligne existe plus loin
            let foundInRight = -1;
            let foundInLeft = -1;
            
            // Chercher line1 dans les prochaines lignes de content2
            for (let k = j + 1; k < Math.min(j + 5, lines2.length); k++) {
                if (lines2[k] === line1) {
                    foundInRight = k;
                    break;
                }
            }
            
            // Chercher line2 dans les prochaines lignes de content1
            for (let k = i + 1; k < Math.min(i + 5, lines1.length); k++) {
                if (lines1[k] === line2) {
                    foundInLeft = k;
                    break;
                }
            }
            
            if (foundInRight !== -1 && (foundInLeft === -1 || foundInRight - j < foundInLeft - i)) {
                // line1 a été supprimée, les lignes avant sont ajoutées
                while (j < foundInRight) {
                    diff.push({
                        type: 'added',
                        lineNumber: j + 1,
                        content: lines2[j],
                        side: 'right'
                    });
                    j++;
                }
            } else if (foundInLeft !== -1) {
                // line2 a été ajoutée, les lignes avant sont supprimées
                while (i < foundInLeft) {
                    diff.push({
                        type: 'removed',
                        lineNumber: i + 1,
                        content: lines1[i],
                        side: 'left'
                    });
                    i++;
                }
            } else {
                // Ligne modifiée
                diff.push({
                    type: 'modified',
                    lineNumber: i + 1,
                    oldContent: line1,
                    newContent: line2
                });
                i++;
                j++;
            }
        }
    }
    
    // Résumé des changements
    const summary = {
        added: diff.filter(d => d.type === 'added').length,
        removed: diff.filter(d => d.type === 'removed').length,
        modified: diff.filter(d => d.type === 'modified').length,
        unchanged: diff.filter(d => d.type === 'unchanged').length,
        totalLines1: lines1.length,
        totalLines2: lines2.length
    };
    
    return { diff, summary };
}

// Route pour obtenir un diff détaillé entre deux contenus
app.post('/compute-diff', (req, res) => {
    const { content1, content2, path1, path2 } = req.body;
    
    if (content1 === undefined || content2 === undefined) {
        return res.status(400).json({ error: "content1 et content2 requis" });
    }
    
    const result = computeDiff(content1, content2);
    result.path1 = path1 || 'Version A';
    result.path2 = path2 || 'Version B';
    
    res.json(result);
});

// Route pour obtenir un diff entre Roblox et le disque pour un script
app.get('/diff-script', (req, res) => {
    const scriptPath = req.query.path;
    const robloxContent = req.query.robloxContent;
    
    if (!scriptPath) {
        return res.status(400).json({ error: "path requis" });
    }
    
    const fullPath = path.join(ROOT_DIR, scriptPath);
    
    if (!fs.existsSync(fullPath)) {
        return res.status(404).json({ error: "Script non trouvé sur le disque" });
    }
    
    const diskContent = fs.readFileSync(fullPath, 'utf8');
    
    if (robloxContent !== undefined) {
        const result = computeDiff(robloxContent, diskContent);
        result.path1 = 'Roblox';
        result.path2 = 'Disque';
        res.json(result);
    } else {
        res.json({ diskContent });
    }
});

// Sauvegarder un script depuis Roblox vers le disque (avec détection de conflit)
app.post('/save-script-from-roblox', (req, res) => {
    const { path: scriptPath, content, className, timestamp, user, machine } = req.body;
    
    if (!scriptPath || content === undefined) {
        return res.status(400).json({ error: "path et content requis" });
    }
    
    // Vérifier si le script est verrouillé par quelqu'un d'autre
    const locks = getActiveLocks();
    const lock = locks[scriptPath];
    if (lock && lock.user !== user) {
        console.log(`🔒 Script verrouillé par ${lock.user}: ${scriptPath}`);
        return res.json({
            success: false,
            locked: true,
            lockedBy: lock.user,
            lockedAt: lock.timestamp,
            machine: lock.machine,
            message: `Ce script est verrouillé par ${lock.user}`
        });
    }
    
    const fullPath = path.join(ROOT_DIR, scriptPath);
    const folderPath = path.dirname(fullPath);
    const newHash = computeHash(content);
    
    try {
        // Vérifier si le fichier existe sur le disque
        if (fs.existsSync(fullPath)) {
            const diskContent = fs.readFileSync(fullPath, 'utf8');
            const diskHash = computeHash(diskContent);
            const diskStats = fs.statSync(fullPath);
            const diskTimestamp = diskStats.mtime.getTime();
            
            // Vérifier si le contenu est différent
            if (diskHash !== newHash) {
                // Le fichier sur le disque est différent de ce qu'on veut sauvegarder
                
                // Récupérer le dernier état connu
                const lastState = lastKnownState[scriptPath];
                
                if (lastState) {
                    // On connaît l'état précédent
                    
                    if (lastState.hash !== diskHash && lastState.hash !== newHash) {
                        // CONFLIT ! Le disque ET Roblox ont été modifiés depuis le dernier état connu
                        console.log(`⚠️ CONFLIT détecté: ${scriptPath}`);
                        console.log(`   Dernier état connu: ${lastState.hash.substring(0, 8)}...`);
                        console.log(`   Version disque: ${diskHash.substring(0, 8)}...`);
                        console.log(`   Version Roblox: ${newHash.substring(0, 8)}...`);
                        
                        return res.json({
                            success: false,
                            conflict: true,
                            path: scriptPath,
                            diskContent: diskContent,
                            diskHash: diskHash,
                            robloxHash: newHash,
                            diskTimestamp: diskTimestamp,
                            message: "Le fichier a été modifié sur le disque ET dans Roblox"
                        });
                    }
                    
                    if (lastState.hash === diskHash) {
                        // Le disque n'a pas changé depuis le dernier état connu
                        // On peut sauvegarder en toute sécurité
                    }
                } else {
                    // Pas d'état connu - première fois qu'on voit ce script
                    // On compare juste si le contenu est différent
                    // Pour éviter les faux positifs, on sauvegarde quand même
                    console.log(`📝 Première sauvegarde de ${scriptPath} (pas d'état précédent)`);
                }
            } else {
                // Le contenu est identique, rien à faire
                return res.json({
                    success: true,
                    unchanged: true,
                    message: "Contenu identique, pas de changement"
                });
            }
        } else {
            // Le fichier n'existe pas, on le crée
            if (!fs.existsSync(folderPath)) {
                fs.mkdirSync(folderPath, { recursive: true });
            }
        }
        
        // Sauvegarder le fichier
        const isNew = !fs.existsSync(fullPath);
        fs.writeFileSync(fullPath, content);
        
        // Mettre à jour l'état connu
        lastKnownState[scriptPath] = {
            source: 'roblox',
            timestamp: Date.now(),
            hash: newHash
        };
        
        // Ajouter à l'historique
        const userName = user || machine || 'unknown';
        addHistoryEntry(scriptPath, isNew ? 'created' : 'modified', userName, {
            source: 'roblox',
            machine: machine,
            linesCount: content.split('\n').length
        });
        
        console.log(`📤 Script sauvegardé depuis Roblox: ${scriptPath}`);
        
        res.json({
            success: true,
            hash: newHash,
            timestamp: Date.now()
        });
        
    } catch (e) {
        console.error(`❌ Erreur sauvegarde ${scriptPath}:`, e.message);
        res.status(500).json({ error: e.message });
    }
});

// Vérifier les conflits bidirectionnels entre Roblox et le disque
app.post('/check-bidirectional-conflicts', (req, res) => {
    const { scripts } = req.body;
    
    if (!scripts || !Array.isArray(scripts)) {
        return res.status(400).json({ error: "scripts array requis" });
    }
    
    const conflicts = [];
    const details = {
        synced: [],
        modifiedLocally: [],
        onlyOnDisk: [],
        onlyInRoblox: []
    };
    
    // Récupérer tous les scripts du disque
    const diskScripts = getGlobalScriptsWithHashes();
    const robloxPaths = new Set();
    
    // Comparer chaque script Roblox avec le disque
    for (const script of scripts) {
        robloxPaths.add(script.path);
        const diskScript = diskScripts[script.path];
        
        if (!diskScript) {
            // Script uniquement dans Roblox
            details.onlyInRoblox.push(script.path);
            continue;
        }
        
        // Comparer les hash
        const robloxHash = script.hash;
        const diskHash = diskScript.hash;
        
        if (robloxHash === diskHash) {
            // Identiques
            details.synced.push(script.path);
        } else {
            // Différents - c'est un conflit potentiel
            // Vérifier le dernier état connu
            const lastState = lastKnownState[script.path];
            
            if (lastState) {
                if (lastState.hash !== diskHash && lastState.hash !== robloxHash) {
                    // Les deux ont changé depuis le dernier état connu = CONFLIT
                    conflicts.push({
                        path: script.path,
                        robloxHash: robloxHash,
                        diskHash: diskHash,
                        diskContent: diskScript.content,
                        lastKnownHash: lastState.hash,
                        type: 'both_modified'
                    });
                } else if (lastState.hash === diskHash) {
                    // Seul Roblox a changé
                    details.modifiedLocally.push(script.path);
                } else if (lastState.hash === robloxHash) {
                    // Seul le disque a changé
                    conflicts.push({
                        path: script.path,
                        robloxHash: robloxHash,
                        diskHash: diskHash,
                        diskContent: diskScript.content,
                        type: 'disk_modified'
                    });
                }
            } else {
                // Pas d'état connu - on considère que c'est une modification locale
                // (l'utilisateur a modifié dans Roblox sans avoir synchronisé avant)
                details.modifiedLocally.push(script.path);
            }
        }
    }
    
    // Scripts uniquement sur le disque
    for (const diskPath in diskScripts) {
        if (!robloxPaths.has(diskPath)) {
            details.onlyOnDisk.push(diskPath);
        }
    }
    
    console.log(`🔍 Vérification bidirectionnelle:`);
    console.log(`   ✅ Synchronisés: ${details.synced.length}`);
    console.log(`   📝 Modifiés localement: ${details.modifiedLocally.length}`);
    console.log(`   💾 Uniquement sur disque: ${details.onlyOnDisk.length}`);
    console.log(`   📗 Uniquement dans Roblox: ${details.onlyInRoblox.length}`);
    console.log(`   ⚠️ Conflits: ${conflicts.length}`);
    
    res.json({
        conflicts: conflicts,
        synced: details.synced.length,
        modified: details.modifiedLocally.length,
        onlyOnDisk: details.onlyOnDisk.length,
        onlyInRoblox: details.onlyInRoblox.length,
        details: details
    });
});

// Mettre à jour l'état connu lors d'un load (pour tracker les changements futurs)
app.post('/update-known-state', (req, res) => {
    const { scripts } = req.body;
    
    if (!scripts || !Array.isArray(scripts)) {
        return res.status(400).json({ error: "scripts array requis" });
    }
    
    for (const script of scripts) {
        const hash = computeHash(script.content || script.source || '');
        lastKnownState[script.path] = {
            source: 'load',
            timestamp: Date.now(),
            hash: hash
        };
    }
    
    console.log(`📋 État connu mis à jour pour ${scripts.length} scripts`);
    res.json({ success: true, updated: scripts.length });
});

// Récupérer l'état de synchronisation actuel
app.get('/sync-status', (req, res) => {
    const diskScripts = getGlobalScriptsWithHashes();
    const status = {
        diskScripts: Object.keys(diskScripts).length,
        knownStates: Object.keys(lastKnownState).length,
        states: {}
    };
    
    for (const [path, state] of Object.entries(lastKnownState)) {
        const diskScript = diskScripts[path];
        status.states[path] = {
            lastSource: state.source,
            lastTimestamp: state.timestamp,
            synced: diskScript ? (state.hash === diskScript.hash) : false
        };
    }
    
    res.json(status);
});

// Route OPTIMISÉE : vérifier les timestamps de plusieurs scripts en 1 requête
app.post('/check-timestamps', (req, res) => {
    const { scripts } = req.body; // Array de chemins de scripts
    
    if (!scripts || !Array.isArray(scripts)) {
        return res.status(400).json({ error: "scripts array required" });
    }
    
    const timestamps = {};
    
    for (const scriptPath of scripts) {
        const fullPath = path.join(ROOT_DIR, scriptPath);
        try {
            if (fs.existsSync(fullPath)) {
                const stats = fs.statSync(fullPath);
                timestamps[scriptPath] = stats.mtime.getTime();
            }
        } catch (e) {
            // Ignorer les erreurs pour ce script
        }
    }
    
    res.json({ timestamps });
});

// --------------------------------------------------------
// 3. HOT RELOAD - WebSocket System (comme Rojo)
// --------------------------------------------------------
const chokidar = require('chokidar');

// Créer le serveur WebSocket
const wss = new WebSocket.Server({ port: WS_PORT });
const connectedClients = new Set();

wss.on('connection', (ws) => {
    console.log('🔌 Client Roblox connecté au WebSocket');
    connectedClients.add(ws);
    
    ws.on('close', () => {
        console.log('🔌 Client Roblox déconnecté');
        connectedClients.delete(ws);
    });
    
    ws.on('error', (error) => {
        console.error('❌ WebSocket error:', error);
        connectedClients.delete(ws);
    });
    
    // Envoyer un message de bienvenue
    ws.send(JSON.stringify({ type: 'connected', message: 'Hot Reload WebSocket actif' }));
});

// Fonction pour notifier tous les clients connectés
function notifyClients(filePath) {
    const message = JSON.stringify({
        type: 'fileChanged',
        path: filePath
    });
    
    connectedClients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(message);
        }
    });
}

// Watcher pour détecter les changements de fichiers .lua (projet principal)
const watchPath = path.join(ROOT_DIR, '**/*.lua');
console.log(`📁 Surveillance du dossier principal: ${watchPath}`);

const watcher = chokidar.watch(watchPath, {
    ignored: /(^|[\/\\])\../, // Ignorer les fichiers cachés
    persistent: true,
    ignoreInitial: true, // Ne pas trigger au démarrage
    usePolling: true, // Force le polling (plus fiable sur Windows)
    interval: 1000, // Vérifier toutes les secondes
    awaitWriteFinish: {
        stabilityThreshold: 500,
        pollInterval: 100
    }
});

watcher
    .on('ready', () => {
        console.log('✅ Watcher principal prêt et en écoute...');
    })
    .on('change', (filePath) => {
        const relativePath = path.relative(ROOT_DIR, filePath).replace(/\\/g, '/');
        console.log(`🔄 Fichier modifié: ${relativePath}`);
        
        // Notifier tous les clients WebSocket
        notifyClients(relativePath);
    })
    .on('add', (filePath) => {
        const relativePath = path.relative(ROOT_DIR, filePath).replace(/\\/g, '/');
        console.log(`➕ Nouveau fichier: ${relativePath}`);
        notifyClients(relativePath);
    })
    .on('error', error => console.error(`❌ Watcher error: ${error}`));

// Watcher pour les dossiers partagés (créé dynamiquement)
let sharedWatcher = null;

function setupSharedFoldersWatcher() {
    // Arrêter l'ancien watcher s'il existe
    if (sharedWatcher) {
        sharedWatcher.close();
    }
    
    const config = loadSharedFoldersConfig();
    const sharedPaths = [];
    
    // Collecter tous les chemins des dossiers partagés activés
    for (const folder of config.shared_folders || []) {
        if (folder.enabled) {
            const resolvedPath = resolveSharedPath(folder.path);
            if (fs.existsSync(resolvedPath)) {
                sharedPaths.push(path.join(resolvedPath, '**/*.lua'));
            }
        }
    }
    
    if (sharedPaths.length === 0) {
        console.log('📁 Aucun dossier partagé activé à surveiller');
        return;
    }
    
    console.log(`📁 Surveillance des dossiers partagés: ${sharedPaths.length} dossier(s)`);
    
    sharedWatcher = chokidar.watch(sharedPaths, {
        ignored: /(^|[\/\\])\../,
        persistent: true,
        ignoreInitial: true,
        usePolling: true,
        interval: 1000,
        awaitWriteFinish: {
            stabilityThreshold: 500,
            pollInterval: 100
        }
    });
    
    sharedWatcher
        .on('ready', () => {
            console.log('✅ Watcher des dossiers partagés prêt');
        })
        .on('change', (filePath) => {
            // Trouver le dossier partagé correspondant
            const config = loadSharedFoldersConfig();
            for (const folder of config.shared_folders || []) {
                const resolvedPath = resolveSharedPath(folder.path);
                if (filePath.startsWith(resolvedPath)) {
                    const relativePath = path.relative(resolvedPath, filePath).replace(/\\/g, '/');
                    const targetPath = folder.target + '/' + relativePath;
                    
                    console.log(`🔄 [PARTAGÉ] ${folder.name}: ${relativePath}`);
                    
                    // Notifier avec le chemin cible dans Roblox
                    connectedClients.forEach(client => {
                        if (client.readyState === WebSocket.OPEN) {
                            client.send(JSON.stringify({
                                type: 'sharedFileChanged',
                                sharedFolder: folder.name,
                                relativePath: relativePath,
                                targetPath: targetPath,
                                sourcePath: filePath
                            }));
                        }
                    });
                    break;
                }
            }
        })
        .on('add', (filePath) => {
            const config = loadSharedFoldersConfig();
            for (const folder of config.shared_folders || []) {
                const resolvedPath = resolveSharedPath(folder.path);
                if (filePath.startsWith(resolvedPath)) {
                    const relativePath = path.relative(resolvedPath, filePath).replace(/\\/g, '/');
                    console.log(`➕ [PARTAGÉ] ${folder.name}: ${relativePath}`);
                    break;
                }
            }
        })
        .on('error', error => console.error(`❌ Shared watcher error: ${error}`));
}

// Démarrer la surveillance des dossiers partagés
setupSharedFoldersWatcher();

// Route pour recharger la configuration des dossiers partagés et redémarrer le watcher
app.post('/shared-folders/reload', (req, res) => {
    setupSharedFoldersWatcher();
    res.json({ success: true, message: "Configuration rechargée, watcher redémarré" });
});

console.log('👀 File watcher activé pour les fichiers .lua');
console.log(`🔌 WebSocket serveur sur le port ${WS_PORT}`);

app.listen(PORT, () => console.log(`🚀 ROBLOX SERVER PRÊT : http://localhost:${PORT}`));
console.log(`📂 Tes fichiers seront dans : ${ROOT_DIR}`);