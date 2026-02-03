# 🧪 PHASE 2 - Testing Guide

## ✅ Backend Status
All Phase 2 backend code is complete:
- ✅ BaseSystem.module.lua
- ✅ DoorSystem.module.lua  
- ✅ GameServer.server.lua (updated)
- ✅ PlayerService.module.lua (updated)
- ✅ NetworkHandler.module.lua (updated)

---

## 🏗️ Step 1: Create Workspace Structure

Before testing, you need to create the bases in Studio Workspace.

### Create Bases Folder

1. In **Workspace**, create a **Folder** named `Bases`

### Create Base_1 (Template)

Inside `Workspace/Bases/`, create a **Model** named `Base_1` with:

#### A. SpawnPoint
- **Type**: Part
- **Name**: `SpawnPoint`
- **Size**: 4, 1, 4
- **Transparency**: 1 (invisible)
- **CanCollide**: false
- **Anchored**: true
- **Position**: Choose a location in your world

#### B. Door Folder
Create a **Folder** named `Door` inside Base_1, containing:

**1. Bars (Model)**
- **Name**: `Bars`
- Add 4-6 **Parts** inside (the actual door bars)
- Each part:
  - **CanCollide**: false (open by default)
  - **Transparency**: 0.8
  - **Anchored**: true
  - **Size**: 0.5, 4, 0.5 (vertical bars)
  - Arrange them like prison bars

**2. ActivationPad (Part)**
- **Name**: `ActivationPad`
- **Size**: 3, 0.5, 3
- **BrickColor**: Bright green
- **CanCollide**: true
- **Anchored**: true
- **Position**: Near the door entrance

#### C. Slots Folder
Create a **Folder** named `Slots` inside Base_1, containing:

**Slot_1 to Slot_30** (30 slots total)
- Each slot is a **Model** named `Slot_1`, `Slot_2`, etc.
- Inside each slot, add a **Part** named `Platform`:
  - **Size**: 3, 0.5, 3
  - **Anchored**: true
  - **CanCollide**: true
  - **BrickColor**: Dark stone grey
  - Arrange them in a grid (6 rows x 5 columns)

#### D. Floors Folder
Create a **Folder** named `Floors` inside Base_1, containing:

**Floor_0** (Ground floor - always visible)
- **Type**: Part
- **Name**: `Floor_0`
- **Size**: 50, 1, 50 (large platform)
- **Transparency**: 0
- **CanCollide**: true
- **Anchored**: true

**Floor_1** (Unlocks at 11 slots - hidden by default)
- **Type**: Part
- **Name**: `Floor_1`
- **Size**: 50, 1, 50
- **Transparency**: 1 (invisible)
- **CanCollide**: false (disabled)
- **Anchored**: true
- **Position**: Above Floor_0 (Y + 15)

**Floor_2** (Unlocks at 21 slots - hidden by default)
- **Type**: Part
- **Name**: `Floor_2`
- **Size**: 50, 1, 50
- **Transparency**: 1 (invisible)
- **CanCollide**: false (disabled)
- **Anchored**: true
- **Position**: Above Floor_1 (Y + 15)

---

### Duplicate for More Bases

Once Base_1 is complete:
1. **Duplicate** Base_1 (Ctrl+D)
2. Rename to `Base_2`
3. Move it to a different location
4. Repeat for Base_3, Base_4, etc. (up to Base_8)

**Tip**: Space bases far apart (at least 100 studs) to avoid overlap.

---

## 🧪 Step 2: Test the Backend

### Test 1: Server Starts Successfully

1. Press **F5** (Play Solo)
2. Check **Output** window for:

```
[GameServer] BaseSystem: OK
[GameServer] DoorSystem: OK
[BaseSystem] X base(s) trouvée(s)
[DoorSystem] CollisionGroups configurés
```

✅ **Expected**: No errors, all systems initialize

---

### Test 2: Base Assignment

1. Play Solo (F5)
2. Check Output for:

```
[BaseSystem] Base_1 assignée à [YourName]
[BaseSystem] [YourName] téléporté à sa base
```

3. Your character should spawn at the SpawnPoint of Base_1

✅ **Expected**: You spawn at your assigned base

---

### Test 3: Door Activation

**Method 1: Touch the ActivationPad**
1. Walk onto the green ActivationPad
2. Check Output for:

```
[NetworkHandler] ActivateDoor reçu de [YourName]
[DoorSystem] Porte fermée pour [YourName] pendant 30s
```

3. The door Bars should become solid (Transparency = 0.3)
4. You should still be able to walk through (owner bypass)

**Method 2: Use TEST_UI button**
1. The TEST_UI script has a "Test Door" button
2. Click it to activate the door remotely

✅ **Expected**: 
- Door closes for 30 seconds
- You get a notification "Door closed for 30 seconds!"
- You can still pass through (owner)
- After 30s, door reopens automatically

---

### Test 4: Door Reopening

1. Activate the door
2. Wait 30 seconds
3. Check Output for:

```
[DoorSystem] Porte rouverte pour [YourName]
```

4. Door Bars should become transparent again (Transparency = 0.8)

✅ **Expected**: Door automatically reopens after 30s

---

### Test 5: Multiple Players (Optional)

1. Use **Test** → **Players** → **2 Players** in Studio
2. Both players should get different bases
3. Player 1 closes their door
4. Player 2 should NOT be able to pass through Player 1's door

✅ **Expected**: Each player has their own base with independent door

---

## 🐛 Common Issues

### Issue: "Dossier Bases introuvable"
**Fix**: Create `Workspace/Bases` folder

### Issue: "0 base(s) trouvée(s)"
**Fix**: Make sure bases are named exactly `Base_1`, `Base_2`, etc.

### Issue: "SpawnPoint introuvable"
**Fix**: Each base needs a Part named `SpawnPoint`

### Issue: Door doesn't close
**Fix**: 
- Check that `Door/Bars` exists in the base
- Check that bars are Parts (not Models)
- Check Output for errors

### Issue: Can't walk through door as owner
**Fix**: This is a CollisionGroup issue - check that PhysicsService is working

---

## 📝 Next Steps

Once backend testing is complete:

### Phase 2 DEV B - Client Controllers
1. Create `BaseController.module.lua` (client-side)
2. Create `DoorController.module.lua` (client-side)
3. Add UI elements for door timer
4. Add visual feedback for door state

### Phase 3 - Economy System
1. Slot purchasing
2. Cash generation
3. Slot cash collection

---

## 🎯 Success Criteria

Phase 2 backend is complete when:
- ✅ Server starts without errors
- ✅ Players are assigned bases automatically
- ✅ Players spawn at their base
- ✅ Door can be activated (closes for 30s)
- ✅ Owner can always pass through their door
- ✅ Door reopens automatically after 30s
- ✅ Multiple players have independent bases

---

**Ready to test? Follow Step 1 to create the Workspace structure!**
