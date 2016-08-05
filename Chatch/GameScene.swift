//
//  GameScene.swift
//  Chatch
//
//  Created by Ben Dunlop on 2016/07/06.
//  Copyright (c) 2016 Luntrun. All rights reserved.
//  Dungeon generation code based on algorithm from RogueBasin by Mike Anderson & DungeonGenerator by Solarnus, Ted Brown
//
//  Most comments below are sadly unhelpful, self-referential; yet enthusiastic

import SpriteKit

//# MARK: - Operator Overloads
//operator overloads for +,-,*,/ that let us use them with CGPoint 2D co-ordinates! Hoo boy!
func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func - (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func * (point: CGPoint, scalar: CGPoint) -> CGPoint {
    return CGPoint(x: point.x * scalar.x, y: point.y * scalar.y)
}

func / (point: CGPoint, scalar: CGPoint) -> CGPoint {
    return CGPoint(x: point.x / scalar.x, y: point.y / scalar.y)
}

//# MARK: - Enums
//let's define our tile data! Whoa man!
enum Tile: Int {
    
    //note to stupid programmer Ben.. the order of the below case list determines 0,1,2,3etc.-ness of the tile array..
    case Rock //0 - Impassable Rock
    case Floor_room //1
    case Wall //2.. etc.
    case Dirt //3 - diggable dirt to fill up most of the dungeon with initially
    case Floor_corridor //4
    case Door_wooden
    
    var description:String {
        switch self {
        case Rock:
            return "Rock (impassable)"
        case Floor_room:
            return "Floor (Room)"
        case Wall:
            return "Wall"
        case Dirt:
            return "Dirt (diggable)"
        case Floor_corridor:
            return "Floor (Corridor)"
        case Door_wooden:
            return "Wooden Door"
        }
    }
    
    var image:String {
        switch self {
        case Rock:
            return "rock_impass"
        case Floor_room:
            return "floor_dirt_ochre"
        case Wall:
            return "wall_brix_grey"
        case Dirt:
            return "dirt_diggable"
        case Floor_corridor:
            return "floor_corridor"
        case .Door_wooden:
            return "door_wooden"
        }
    }
}

//# MARK: - Main Class
//ohhh here come dat GameScene class...
class GameScene: SKScene {
    
    //------------------------------------------------
    //# MARK: - Dungeon Constants
    //some dungeon constants
    let max_rm_w = 6
    let max_rm_h = 6
    let max_corr_l = 10
    let tileRockImpass = Tile.Rock.rawValue
    let tileWall = Tile.Wall.rawValue
    let tileUnusedDirt = Tile.Dirt.rawValue
    let tileFloorRoom = Tile.Floor_room.rawValue
    let tileFloorCorridor = Tile.Floor_corridor.rawValue
    let tileDoor = Tile.Door_wooden.rawValue
    
    //# MARK: - Dungeon Variables
    //some dungeon variables
    var dungWidth = 40          //initial max dungeon width (x)
    var dungHeight = 60         //initial max dungeon height (y)
    var dungeon_map = [Int]()   //our map
    var oldseed = 0             //the old seed from the RNG is saved in this one
    var corr_room = false
    var objects = 20            //number of "objects" to generate on the map
    var chanceRoom = 50         //define the %chance to generate either a room or a corridor on the map
    var chanceCorridor = 50     //BTW, rooms are 1st priority so actually it's enough to just define the chance of generating a room
    var countingTries = 0
    var prevFeature = ""        //this string is used by random dungeon gen to ensure rooms adjoining rooms share the same wall (also hoping for 'rooms come after corridors' logic..)
    var prevMod = 0
    
    //------------------------------------------------
    
    //reqd initializer
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // hello player
    let player = SKSpriteNode(imageNamed: "player_onionman")
    
    //here's the view constants
    let view2D:SKSpriteNode
    let viewIso:SKSpriteNode
    
    //here's the tilemap constants
    let tileSize = (width:16, height:16)
    
    //our class initialisation
    override init(size: CGSize){
        view2D = SKSpriteNode()
        viewIso = SKSpriteNode()
        
        super.init(size: size)
        self.anchorPoint = CGPoint(x:0.5, y:0.5)
    }
    
    //# MARK: - didMoveToView
    override func didMoveToView(view: SKView) {
        
        //write a pretty heading somewhere near the top of the screen
        let gameTitleLabel = SKLabelNode(fontNamed:"Calibri")
        gameTitleLabel.text = "Chatch!"
        gameTitleLabel.fontSize = 9
        gameTitleLabel.position = CGPoint(x:CGRectGetMidX(self.frame), y:CGRectGetMaxY(self.frame)-10)
        self.addChild(gameTitleLabel)
        
        //constantly adjusts the scale to fit dynamically to the screen size of whatever device you’re testing on
        let deviceScale = self.size.width/667
        
        //position our 2 sub views so we can easily see and interact with either/or
        view2D.position = CGPoint(x:-self.size.width*0.48, y:self.size.height*0.47)
        view2D.xScale = deviceScale
        view2D.yScale = deviceScale
        addChild(view2D)
    
        //1. Create the dungeon yo
        dungeonCreate(40,iny: 60,inobj: 50)
        
    }
    
    //# MARK: - Dungeon Create Function
    //function to create dungeon...
    func dungeonCreate(inx:Int, iny:Int, inobj:Int) {
        
        // Adjust objects size if too small, otherwise cool dude
        if (inobj < 1) { objects = 10 }
        else { objects = inobj }
        
        // Adjust the size of the map if it's too small
        if (inx < 3) { dungWidth = 3 }
        else { dungWidth = inx }
        if (iny < 3) { dungHeight = 3 }
        else { dungHeight = iny }
        
        //define map size
        dungeon_map = [dungWidth * dungHeight]
        
        //start with making the "standard stuff" on the map
        for y in 0..<dungHeight {
            for x in 0..<dungWidth {
                
                //ie, making the borders of unwalkable walls
                if (y == 0) { createCell(x, y: y, celltype: tileRockImpass) }
                else if (y == dungHeight-1) { createCell(x, y: y, celltype: tileRockImpass) }
                else if (x == 0) { createCell(x, y: y, celltype: tileRockImpass) }
                else if (x == dungWidth-1) { createCell(x, y: y, celltype: tileRockImpass) }
                
                //and fill the rest with diggable dirt
                else { createCell(x, y: y, celltype: tileUnusedDirt) }
                
                
            }
        }
        
        /* ------------------------------------------------
         Now we start doing some random dungeon generation!
         ----------------------------------------------- */
        
        //start with making a room in the middle, which we can start building upon
        makeRoom(dungWidth/2, y: dungHeight/2, xlength: max_rm_w, ylength: max_rm_h, direction: getRand(0,max: 3));
        
        //keep count of the number of "objects" we've made
        var currentFeatures = 1 //+1 for the first room we just made
        
        for countingTries in 0..<1000 {
            
            //have we reached our object quota?
            if (currentFeatures == objects) {
                break
            }
            
            //start with a random wall
            var newx = 0
            var xmod = 0
            var newy = 0
            var ymod = 0
            var validTile = -1
            
            //there's a 1000 chances to find a suitable object (room or corridor)
            for testing in 0..<1000 {
                newx = getRand(1, max: dungWidth-1)
                newy = getRand(1, max: dungHeight-1)
                validTile = -1
                
                if (getCell(newx, y: newy) == tileWall || getCell(newx, y: newy) == tileFloorCorridor) {
                    //check if we can reach the place
                    if (getCell(newx, y: newy+1) == tileFloorRoom || getCell(newx, y: newy+1) == tileFloorCorridor) {
                        validTile = 0 //
                        xmod = 0
                        ymod = -1
                    }
                    else if (getCell(newx-1, y: newy) == tileFloorRoom || getCell(newx-1, y: newy) == tileFloorCorridor) {
                        validTile = 1 //
                        xmod = +1
                        ymod = 0
                    }
                        
                    else if (getCell(newx, y: newy-1) == tileFloorRoom || getCell(newx, y: newy-1) == tileFloorCorridor) {
                        validTile = 2 //
                        xmod = 0
                        ymod = +1
                    }
                        
                    else if (getCell(newx+1, y: newy) == tileFloorRoom || getCell(newx+1, y: newy) == tileFloorCorridor) {
                        validTile = 3 //
                        xmod = -1
                        ymod = 0
                    }
                    
                    //check that we haven't got another door nearby, so we won't get alot of openings besides each other
                    if (validTile > -1) {
                        if (getCell(newx, y: newy+1) == tileDoor) { //north
                            validTile = -1 }
                        else if (getCell(newx-1, y: newy) == tileDoor) { //east
                            validTile = -1 }
                        else if (getCell(newx, y: newy-1) == tileDoor) { //south
                            validTile = -1 }
                        else if (getCell(newx+1, y: newy) == tileDoor) { //west
                            validTile = -1 }
                    }
                    
                    //if we can, jump out of the loop and continue with the rest
                    if (validTile > -1) { break }
                }
            }
            
            if (validTile > -1) {
                
                //choose what to build now at our newly found place, and at what direction
                var feature = getRand(0, max: 100)
                
                //if previous feature was a corridor, make sure next one is a room
                if (prevFeature == "corridor") { feature = 0 }
                
                if (feature <= chanceRoom) { //a new room
                    if (makeRoom((newx+xmod), y: (newy+ymod), xlength: max_rm_w, ylength: max_rm_h, direction: validTile)) {
                        currentFeatures += 1; //add to our quota
                        
                        //then we mark the wall opening with a door
                        setCell(newx, y: newy, celltype: tileDoor);
                        
                        //clean up infront of the door so we can reach it .. ben changed it to be a door, from empty space
                        //setCell((newx+xmod), y: (newy+ymod), celltype: tileDoor);
                        
                        //so last made feature was a room
                        prevFeature = "room"
                    }
                }
                    
                else if (feature >= chanceRoom) { //new corridor
                    if (makeCorridor((newx+xmod), y: (newy+ymod), lenght: max_corr_l, direction: validTile)) {
                        //same thing here, add to the quota and a door
                        currentFeatures += 1;
                        if (corr_room) {
                            currentFeatures += 1;
                            corr_room = false;
                        }
                        setCell(newx, y: newy, celltype: tileDoor);
                        
                        //so last made feature was a corridor
                        prevFeature = "corridor"
                    }
                }
            }
            
        }
        
        //fix dead-end corridors
        fixDeadEndCorridors()
        
        //fix up the wall corners
        fixWallCorners()
        
        //All done! Now draw the defined dungeon to screen..
        dungeonPrint()
    }
    
    //# MARK: - Room Element Creation Functions
    
    //function for carving out a random room! Hoo baby boy and baby girl
    func makeRoom(x:Int, y:Int, xlength:Int, ylength:Int, direction:Int) -> Bool {
        
        //lets define the room dimensions! Should be minimum 4x4. (2x2 is walkable space... rest is walls)
        let xlen = Int(arc4random_uniform(UInt32(xlength))+4)
        let ylen = Int(arc4random_uniform(UInt32(xlength))+4)
        
        //choose the direction it's going to be pointing at..
        var dir = 0
        if (direction > 0 && direction < 4) {
            dir = direction
        }
        
        //directional case switch y'all
        switch dir {
        case 0: //North
            
            //Is there enough space to place it?
            for ytemp in y.stride(to: (y-ylen), by: -1) { //reverse count array
                if (ytemp < 0 || ytemp > dungHeight) { return false }
                for xtemp in (x-xlen/2)..<(x+(xlen+1)/2) {
                    if (xtemp < 0 || xtemp > dungWidth) { return false }
                    if (getCell(xtemp, y: ytemp) != tileUnusedDirt) { return false; } //no space left, assuming because there's another already-created room/passageway that isn't dirt (ie. unused tile)
                }
                
            }
            
            //we're still here, build
            for ytemp in y.stride(to: (y-ylen), by: -1) { //reverse count array
                for xtemp in (x-xlen/2)..<(x+(xlen+1)/2) {
                    
                    //start with the walls
                    //left-hand wall
                    if (xtemp == (x-xlen/2)) {
                        //check there's not an existing wall on left, we don't want double walls
                        if (getCell(xtemp-1, y: (ytemp)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //right-hand wall
                    else if (xtemp == (x+(xlen-1)/2)) {
                        //check there's not an existing wall on right, we don't want double walls
                        if (getCell(xtemp+1, y: (ytemp)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //bottom wall (not bottom left/right corner, those are handled by left/right wall section)
                    else if (ytemp == y) {
                        //check there's not an existing wall below, we don't want double walls
                        if (getCell(xtemp, y: (ytemp+1)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //top wall
                    else if (ytemp == (y-ylen+1)) {
                        //check there's not an existing wall above, we don't want double walls
                        if (getCell(xtemp, y: (ytemp-1)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    
                    //and then fill with the Ground (floor)
                    else { setCell(xtemp, y: (ytemp+prevMod), celltype: tileFloorRoom ) }
                }
            }
            
            break
           
        case 1: //east
            
            //Is there enough space to place it?
            for ytemp in (y-ylen/2)..<(y+(ylen+1)/2) {
                if (ytemp < 0 || ytemp > dungHeight) { return false }
                for xtemp in x..<(x+xlen) {
                    if (xtemp < 0 || xtemp > dungWidth) { return false }
                    if (getCell(xtemp, y: ytemp) != tileUnusedDirt) { return false } //no space left...
                }
            }
            
            //we're still here, build
            for ytemp in (y-ylen/2)..<(y+(ylen+1)/2) {
                for xtemp in x..<(x+xlen){
                    
                    //start with the walls
                    //left-hand wall
                    if (xtemp == x) {
                        //check there's not an existing wall on left, we don't want double walls
                        if (getCell(xtemp-1, y: (ytemp)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //right-hand wall
                    else if (xtemp == (x+xlen-1)) {
                        //check there's not an existing wall on right, we don't want double walls
                        if (getCell(xtemp+1, y: (ytemp)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //bottom wall (not bottom left/right corner, those are handled by left/right wall section)
                    else if (ytemp == (y-ylen/2)) {
                        //check there's not an existing wall below, we don't want double walls
                        if (getCell(xtemp, y: (ytemp+1)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //top wall
                    else if (ytemp == (y+(ylen-1)/2)) {
                        //check there's not an existing wall above, we don't want double walls
                        if (getCell(xtemp, y: (ytemp-1)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                        
                    //and then fill with the Ground (floor)
                    else { setCell(xtemp, y: ytemp, celltype: tileFloorRoom ) }
                }
            }
            
            break
            
        case 2: //south
            
            //Is there enough space to place it?
            for ytemp in y..<(y+ylen){
                if (ytemp < 0 || ytemp > dungHeight) { return false }
                for xtemp in (x-xlen/2)..<(x+(xlen+1)/2){
                    if (xtemp < 0 || xtemp > dungWidth) { return false }
                    if (getCell(xtemp, y: ytemp) != tileUnusedDirt) { return false } //no space left...
                }
            }
            
            //we're still here, build
            for ytemp in y..<(y+ylen){
                for xtemp in (x-xlen/2)..<(x+(xlen+1)/2){
                    
                    //start with the walls
                    //left-hand wall
                    if (xtemp == (x-xlen/2)) {
                        //check there's not an existing wall on left, we don't want double walls
                        if (getCell(xtemp-1, y: (ytemp)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //right-hand wall
                    else if (xtemp == (x+(xlen-1)/2)) {
                        //check there's not an existing wall on right, we don't want double walls
                        if (getCell(xtemp+1, y: (ytemp)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //top wall
                    else if (ytemp == y) {
                        //check there's not an existing wall below, we don't want double walls
                        if (getCell(xtemp, y: (ytemp-1)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //bottom wall
                    else if (ytemp == (y+ylen-1)) {
                        //check there's not an existing wall above, we don't want double walls
                        if (getCell(xtemp, y: (ytemp+1)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                        
                    //and then fill with the Ground (floor)
                    else { setCell(xtemp, y: ytemp, celltype: tileFloorRoom ) }
                }
            }
            
            break
            
        case 3: //west
            
            //Is there enough space to place it?
            for ytemp in (y-ylen/2)..<(y+(ylen+1)/2) {
                if (ytemp < 0 || ytemp > dungHeight) { return false }
                for xtemp in x.stride(to: (x-xlen), by:-1) { //reverse count array
                    if (xtemp < 0 || xtemp > dungWidth) { return false }
                    if (getCell(xtemp, y: ytemp) != tileUnusedDirt) { return false } //no space left...
                }
            }
            
            //we're still here, build
            for ytemp in (y-ylen/2)..<(y+(ylen+1)/2) {
                for xtemp in x.stride(to: (x-xlen), by:-1) { //reverse count array
                    
                    //start with the walls
                    //...left-hand wall?
                    if (xtemp == x) {
                        //check there's not an existing wall on left, we don't want double walls
                        if (getCell(xtemp+1, y: (ytemp)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //right-hand wall? hmm.
                    else if (xtemp == (x-xlen+1)) { setCell(xtemp, y: (ytemp), celltype: tileWall ) }
                    //bottom wall (not bottom left/right corner, those are handled by left/right wall section)
                    else if (ytemp == (y-ylen/2)) {
                        //check there's not an existing wall below, we don't want double walls
                        if (getCell(xtemp, y: (ytemp+1)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }
                    //top wall
                    else if (ytemp == (y+(ylen-1)/2)) {
                        //check there's not an existing wall above, we don't want double walls
                        if (getCell(xtemp, y: (ytemp-1)) != tileWall) {
                            setCell(xtemp, y: (ytemp), celltype: tileWall )
                        } else {
                            setCell(xtemp, y: (ytemp), celltype: tileFloorRoom )
                        }
                    }

                    else {
                        setCell(xtemp, y: ytemp, celltype: tileFloorRoom)
                    }
                }
            }
            
            break
            
        default: () //default case, because Swift
            
        }
        
        //yay, all done
        return true
    }
    
    //function for making random corridors...
    func makeCorridor(x:Int, y:Int, lenght:Int, direction:Int) -> Bool {
        
        //define the width/height of the corridor
        let len = getRand(2, max: lenght)
        //let len = Int(arc4random_uniform(UInt32((max:lenght-2)+2))) //hmm.. this may not work...
        var dir = 0
        if (direction > 0 && direction < 4) { dir = direction }
        
        var xtemp = 0
        var ytemp = 0
        var lastX = 0 //used for generation of rooms at end of corridors
        var lastY = 0 //used for generation of rooms at end of corridors
        
        //reject corridors that are out of bounds
        if (x < 0 || x > dungWidth) { return false }
        if (y < 0 || x > dungHeight) { return false }
        
        switch dir {
            
        case 0: //north
            
            xtemp = x
            ytemp = y
            
            //make sure it's not out of the boundaries
            for ytemp in y.stride(to: (y-len), by: -1) {
                if (ytemp < 0 || ytemp > dungHeight) { return false } //sadly, twas out of bounds
                if (getCell(xtemp, y: ytemp) != tileUnusedDirt) { return false } //already in use
            }
            
            //we're still fine? well then, go ahead and build!
            for ytemp in y.stride(to: (y-len), by: -1) {
                setCell(xtemp, y: ytemp, celltype: tileFloorCorridor)
                lastX = xtemp
                lastY = ytemp - 1
            }
            
            break
            
        case 1: //east
            
            ytemp = y
            xtemp = x
            
            //make sure it's not out of the boundaries
            for xtemp in x..<(x+len) {
                if (xtemp < 0 || xtemp > dungWidth) { return false } //sadly, twas out of bounds
                if (getCell(xtemp, y: ytemp) != tileUnusedDirt ) { return false } //already in use
            }
            
            //we're still fine? well then, go ahead and build!
            for xtemp in x..<(x+len) {
                setCell(xtemp, y: ytemp, celltype: tileFloorCorridor)
                lastX = xtemp + 1
                lastY = ytemp
            }
            
            break
            
        case 2: //south
            
            xtemp = x
            ytemp = y
            
            //make sure it's not out of the boundaries
            for ytemp in y..<(y+len) {
                if (ytemp < 0 || ytemp > dungHeight) { return false } //sadly, twas out of bounds
                if (getCell(xtemp, y: ytemp) != tileUnusedDirt ) { return false } //already in use
            }
            
            //we're still fine? well then, go ahead and build!
            for ytemp in y..<(y+len) {
                setCell(xtemp, y: ytemp, celltype: tileFloorCorridor)
                lastX = xtemp
                lastY = ytemp + 1
            }
            
            break
            
        case 3: //west
            
            ytemp = y
            xtemp = x
            
            //make sure it's not out of the boundaries
            for xtemp in x.stride(to: (x-len), by: -1) {
                if (xtemp < 0 || xtemp > dungWidth) { return false }
                if (getCell(xtemp, y: ytemp) != tileUnusedDirt ) { return false }
            }
            
            for xtemp in x.stride(to: (x-len), by: -1) {
                setCell(xtemp, y: ytemp, celltype: tileFloorCorridor)
                lastX = xtemp - 1
                lastY = ytemp
            }
            
            break
            
        default: () //default case, because Swift
            
        }
        
        //debugPrint("Corridor room stuffs... x:"+String(lastX)+" y:"+String(lastY)+" xlength:"+String(max_rm_w)+" ylength:"+String(max_rm_h)+" direction:"+String(direction)+" .")
        
        //try making a room at the end of the corridor
        if (makeRoom(lastX, y: lastY, xlength: max_rm_w, ylength: max_rm_h, direction: dir)) {
            corr_room = true
            
            //then we mark the wall opening with a door
            switch dir {
            case 0: //north
                setCell(lastX, y: lastY, celltype: tileDoor)
            case 1: //east
                setCell(lastX, y: lastY, celltype: tileDoor)
            case 2: //south
                setCell(lastX, y: lastY, celltype: tileDoor)
            case 3: //west
               setCell(lastX, y: lastY, celltype: tileDoor)
            default: () //default case, because Swift
                
            }

            //clean up infront of the door so we can reach it
            //setCell(xtemp, y: ytemp, celltype: tileFloorCorridor ); //COMMENT THIS LINE OUT
        }
        
        //woot, we're still here LOL! Let's inform the other dudes we're done! Huzzah!
        return true
    }
    
    //# MARK: - Room Cleanup Functions
    
    //function for fixing up missing room wall corners and left/right tiles
    func fixWallCorners() {

        //go through whole dungeon map array
        for y in 0..<dungHeight {
            for x in 0..<dungWidth {
                
                //don't check the impassable border coords, obviously
                if ((y != 0) && (y != dungHeight-1) && (x != 0) && (x != dungWidth-1)){
                 
                    /*
                     
                     ? = unsure/any tile type
                     W = Wall, or Door
                     F = Dirt room floor
                     
                     ???
                     WFW
                     ???
                     //above, the D is being set to a Wall
                    */
                    if ((getCell(x, y: y) == tileFloorRoom) && (getCell(x-1, y: y) == tileWall) && (getCell(x+1, y: y) == tileWall)){
                        setCell(x, y: y, celltype: tileWall)
                    }
                    
                    /*
                     FW
                     W?
                     //and in this and below instances, the ? is being set to a Wall
                    */
                    if (((getCell(x-1, y: y) == tileWall) || (getCell(x-1, y: y) == tileDoor)) && ((getCell(x, y: y-1) == tileWall) || (getCell(x, y: y-1) == tileDoor)) && (getCell(x-1, y: y-1) == tileFloorRoom)){
                        setCell(x, y: y, celltype: tileWall)
                    }
                    
                    /*
                     WF
                     ?W
                     */
                    if (((getCell(x+1, y: y) == tileWall) || (getCell(x+1, y: y) == tileDoor)) && ((getCell(x, y: y-1) == tileWall) || (getCell(x, y: y-1) == tileDoor)) && (getCell(x+1, y: y-1) == tileFloorRoom)){
                        setCell(x, y: y, celltype: tileWall)
                    }
                    
                    /*
                     ?W
                     WF
                     */
                    if (((getCell(x+1, y: y) == tileWall) || (getCell(x+1, y: y) == tileDoor)) && ((getCell(x, y: y+1) == tileWall) || (getCell(x, y: y+1) == tileDoor)) && (getCell(x+1, y: y+1) == tileFloorRoom)){
                        setCell(x, y: y, celltype: tileWall)
                    }
                    
                    /*
                     W?
                     FW
                     */
                    if (((getCell(x-1, y: y) == tileWall) || (getCell(x-1, y: y) == tileDoor)) && ((getCell(x, y: y+1) == tileWall) || (getCell(x, y: y+1) == tileDoor)) && (getCell(x-1, y: y+1) == tileFloorRoom)){
                        setCell(x, y: y, celltype: tileWall)
                    }
                    
                    /*
                     
                     D = Unused Dirt
                     
                     ?F?
                     WDW
                     ?F?
                     */
                    if ((getCell(x, y: y) == tileUnusedDirt) && ((getCell(x, y: y-1) == tileFloorRoom) || (getCell(x, y: y+1) == tileFloorRoom)) && ((getCell(x-1, y: y) == tileWall) || (getCell(x-1, y: y) == tileDoor)) && ((getCell(x+1, y: y) == tileWall) || (getCell(x+1, y: y) == tileDoor))){
                        setCell(x, y: y, celltype: tileWall)
                    }
                }
            }
        }
        
    } //end of fixWallCorners()
    
    //remove any dead-end corridors (REMOVED: or put doors on ones that end in walls)
    func fixDeadEndCorridors() {
        
        //go through whole dungeon map array
        for y in 0..<dungHeight {
            for x in 0..<dungWidth {
                
                //don't check the impassable border coords, obviously
                if ((y != 0) && (y != dungHeight-1) && (x != 0) && (x != dungWidth-1)){
                    /*
                     
                    C = Corridor
                    D = Dirt (diggable)
                    W = Room Wall
                     
                    //east
                    CCD/W
 
                    */
                    if (((getCell(x+1, y: y) == tileUnusedDirt) || (getCell(x+1, y: y) == tileWall) || (getCell(x+1, y: y) == tileRockImpass)) && (getCell(x, y: y) == tileFloorCorridor) && (getCell(x-1, y: y) == tileFloorCorridor)){
                        switch (getCell(x+1, y: y)) {
                        
                        //if there's a wall at the end of the corridor, turn it into a door
                        //case tileWall:
                        //    setCell(x+1, y: y, celltype: tileDoor)
                        
                        //go backwards along corridor, making corridor dirt
                        default:
                            runCorriLoop: for j in x.stride(to: 0, by: -1) {
                                if ((getCell(j, y: y) != tileDoor) && (getCell(j, y: y) == tileFloorCorridor)) {
                                    setCell(j, y: y, celltype: tileUnusedDirt)
                                } else {
                                    setCell(j, y: y, celltype: tileWall)
                                    break runCorriLoop
                                }
                            }
                        }
                    } // end of if getCell
                    /*
                     
                     //west
                     D/WCC
                     
                     */
                    if (((getCell(x-1, y: y) == tileUnusedDirt) || (getCell(x-1, y: y) == tileWall) || (getCell(x-1, y: y) == tileRockImpass)) && (getCell(x, y: y) == tileFloorCorridor) && (getCell(x+1, y: y) == tileFloorCorridor)){
                        switch (getCell(x-1, y: y)) {
                            
                        //if there's a wall at the end of the corridor, turn it into a door
                        //case tileWall:
                        //    setCell(x-1, y: y, celltype: tileDoor)
                            
                        //go backwards along corridor, making corridor dirt
                        default:
                            runCorriLoop: for j in x.stride(to: dungWidth, by: 1) {
                                if ((getCell(j, y: y) != tileDoor) && (getCell(j, y: y) == tileFloorCorridor)) {
                                    setCell(j, y: y, celltype: tileUnusedDirt)
                                } else {
                                    setCell(j, y: y, celltype: tileWall)
                                    break runCorriLoop
                                }
                            }
                        }
                    } // end of if getCell
                    /*
                     
                     //south
                     C
                     C
                     D/W
                          BEN IS MESSING AROUND HERE
                     */
                    if (((getCell(x, y: y+1) == tileUnusedDirt) || (getCell(x, y: y+1) == tileWall) || (getCell(x, y: y+1) == tileRockImpass)) && (getCell(x, y: y) == tileFloorCorridor) && (getCell(x, y: y-1) == tileFloorCorridor)){
                        switch (getCell(x, y: y+1)) {
                            
                        //if there's a wall at the end of the corridor, turn it into a door
                        //case tileWall:
                        //    setCell(x, y: y+1, celltype: tileDoor)
                            
                        //go backwards along corridor, making corridor dirt
                        default:
                            runCorriLoop: for j in y.stride(to: 0, by: -1) {
                                if ((getCell(x, y: j) != tileDoor) && (getCell(x, y: j) == tileFloorCorridor)) {
                                    setCell(x, y: j, celltype: tileUnusedDirt)
                                } else {
                                    setCell(x, y: j, celltype: tileWall)
                                    break runCorriLoop
                                }
                            }
                        }
                    } // end of if getCell
                    /*
                     
                     //north
                     D/W
                     C
                     C
                     
                     */
                    if (((getCell(x, y: y-1) == tileUnusedDirt) || (getCell(x, y: y-1) == tileWall) || (getCell(x, y: y-1) == tileRockImpass)) && (getCell(x, y: y) == tileFloorCorridor) && (getCell(x, y: y+1) == tileFloorCorridor)){
                        switch (getCell(x, y: y-1)) {
                            
                        //if there's a wall at the end of the corridor, turn it into a door
                        //case tileWall:
                        //    setCell(x, y: y-1, celltype: tileDoor)
                            
                        //go backwards along corridor, making corridor dirt
                        default:
                            runCorriLoop: for j in y.stride(to: dungHeight, by: 1) {
                                if ((getCell(x, y: j) != tileDoor) && (getCell(x, y: j) == tileFloorCorridor)) {
                                    setCell(x, y: j, celltype: tileUnusedDirt)
                                } else {
                                    setCell(x, y: j, celltype: tileWall)
                                    break runCorriLoop
                                }
                            }
                        }
                    } // end of if getCell
                    
                } //end of impassable if
                
            } //end of x for loop
        } //end of y for loop
        
    } // end of fixDeadEndCorridors()
    
    //# MARK: - Dungeon Drawing/Cell Set or Place Functions
    //the actual physical tile placement on the 2d view
    func placeTile2D(image:String, withPosition:CGPoint){
        let tileSprite = SKSpriteNode(imageNamed: image)
        tileSprite.position = withPosition
        tileSprite.anchorPoint = CGPoint(x:0, y:0)
        view2D.addChild(tileSprite)
    }
    
    //function that places all tiles as defined in our dungeon_map
    func dungeonPrint() {
        for i in 0..<dungHeight {
            for j in 0..<dungWidth {
                //the x/y coord we're dealing with
                let point = CGPoint(x: (j*tileSize.width), y: -(i*tileSize.height))
                
                //find out what the tile type is at dungeon_map's x/y
                let whatTile = getCell(j,y: i)
                let tile = Tile(rawValue: whatTile)!
                
                //actually place the tile
                placeTile2D(tile.image, withPosition:point)
            }
        }
        
    }
    
    //setting a tile's type .. used subsequent to dungeon_map creation
    func setCell(x:Int, y:Int, celltype:Int) {
        dungeon_map[x + dungWidth * y] = celltype
    }
    
    //creating the cells in dungeon_map.. gets called at very beginning on dungeon creation
    func createCell(x:Int, y:Int, celltype:Int) {
        dungeon_map.insert(celltype, atIndex:x + dungWidth * y)
    }
    
    //returns the type of a tile
    func getCell(x:Int, y:Int) -> Int{
        return dungeon_map[x + dungWidth * y]
    }
    
    //# MARK: - Random math functions
    //The RNG. the seed is based on seconds from the "java epoch" ( I think..)
    //perhaps it's the same date as the unix epoch
    //Update:Java Date/Random have been removed in favor of Swift arc4random_uniform()
    func getRand(min:Int, max:Int) -> Int {
        let seed = Int(arc4random_uniform(1000)) + oldseed
        oldseed = seed
        
        let n = max - min + 1;
        var i = Int(arc4random_uniform(UInt32(n)))
        if (i < 0) { i = -i }
        
        //print("seed: " + seed + "\tnum:  " + (min + i));
        return min + i
    }
    
}

//# TODO: - Entity/Player/Monster Classes

//general entity class
class Entity {
    var column: Int = 0
    var row: Int = 0
    var sprite: SKSpriteNode?
    var hitpoints: Int = 1
    enum material {
        case Flesh
        case Wood
        case Stone
        case Metal
        case Water
        case Air
    }
    var onFire: Bool = false
    
}

//M-M-M-Monster Class! A league of its own.
class Monster: Entity {
    var species: String = "unknown"
    var name: String = "monster"
    
}

//A miserable little pile of secrets
class Player: Monster {
    
}



/*
 
 
 
 /////////////// other old stuff //////////////////////
 
 func random() -> CGFloat {
 return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
 }
 
 func random(min min: CGFloat, max: CGFloat) -> CGFloat {
 return random() * (max - min) + min
 }
 
 func addMonster() {
 
 // Create sprite
 let monster = SKSpriteNode(imageNamed: "monster_oldman")
 
 // Determine where to spawn the monster along the Y axis
 let actualY = random(min: monster.size.height/2, max: size.height - monster.size.height/2)
 
 // Position the monster slightly off-screen along the right edge,
 // and along a random position along the Y axis as calculated above
 monster.position = CGPoint(x: size.width + monster.size.width/2, y: actualY)
 
 // Add the monster to the scene
 addChild(monster)
 
 // Determine speed of the monster
 let actualDuration = random(min: CGFloat(2.0), max: CGFloat(4.0))
 
 // Create the actions
 let actionMove = SKAction.moveTo(CGPoint(x: -monster.size.width/2, y: actualY), duration: NSTimeInterval(actualDuration))
 let actionMoveDone = SKAction.removeFromParent()
 monster.runAction(SKAction.sequence([actionMove, actionMoveDone]))
 }
 
 ////////////////////////////////////////////////////
 
class GameScene: SKScene {
 
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
       /* Called when a touch begins */
 
        for touch in touches {
            let location = touch.locationInNode(self)
            
            let sprite = SKSpriteNode(imageNamed:"Spaceship")
            
            sprite.xScale = 0.5
            sprite.yScale = 0.5
            sprite.position = location
            
            let action = SKAction.rotateByAngle(CGFloat(M_PI), duration:1)
            
            sprite.runAction(SKAction.repeatActionForever(action))
            
            self.addChild(sprite)
        }
    }
   
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
    }
}
 
 
 ///in run game thing place mode area idea mugh /////
 //make monsters appear forever!
 /*runAction(SKAction.repeatActionForever(
 SKAction.sequence([
 SKAction.runBlock(addMonster),
 SKAction.waitForDuration(1.0)
 ])
 ))
 
 //didmovestuffs
 
 // 2
 //backColor = SKColor.blackColor()
 // 3
 // player.setScale(1.5)
 // player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
 // 4
 // addChild(player)
 
 */
 */
