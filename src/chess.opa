// 
//  chess.opa
//  chess
//  
//  Created by Mads Hartmann Jensen on 2011-07-31.
//  Copyright 2011 Sideways Coding. All rights reserved.
// 

package chess.chess

import chess.types
import chess.game 
import stdlib.web.template
import stdlib.core.map
import stdlib.core

Column = {{
    
    to_int(x: string): int = String.byte_at_unsafe(0, x)
    
    from_int(x: int): string = Text.to_string(Text.from_character(x))
    
    next(letter: string): string = 
        Column.to_int(letter) |> x -> Column.from_int(x+1)
    
}}

/*
    {Misc functions}
*/

colorc_to_string = 
    | {white} -> "white"
    | {black} -> "black"

kind_to_string = 
    | {king}   -> "king"
    | {queen}  -> "queen"
    | {rook}   -> "rook"
    | {bishop} -> "bishop"
    | {knight} -> "knight"
    | {pawn}   -> "pawn"

domToList(dom: dom): list(dom) = Dom.fold( dom,acc -> [dom|acc], [], dom) |> List.rev(_)

duplicate(x, xs) = match x with
    | 0 -> xs
    | x -> duplicate(x-1,List.append(xs,xs))

create_string_map(xs: list((string,'a))): stringmap('a) = 
    List.fold( tuple,map -> StringMap_add(tuple.f1,tuple.f2,map),xs,StringMap_empty)

create_int_map(xs: list((int,'a))): intmap('a) = 
    List.fold( tuple,map -> IntMap_add(tuple.f1,tuple.f2,map),xs,IntMap_empty)
    

/*
    {Board module}
    
    Represents the actual board game. Keeps per user information about .... 
*/

Board = {{
    
    prepare(board: board): void = 
        do Dom.select_raw("tr") |> domToList(_) |> List.rev(_) |> List.iteri(rowi,tr -> 
            Dom.select_children(tr) |> domToList(_) |> List.iteri(columi, td -> 
                do colorize(rowi+1,columi+1,td,board)
                do labelize(rowi+1,columi+1,td,board)
                do add_on_click_events(rowi+1,columi+1,td,board)
                void
            ,_)
        ,_)
        do place_pieces(board)
        void        

    place_pieces(board: board) = 
        do Dom.select_raw("td img") |> Dom.remove(_)
        do Map.To.val_list(board.chess_positions) |> List.iter(column ->  
            Map.To.val_list(column) |> List.iter(pos -> 
                Option.iter( piece -> 
                    img = Dom.of_xhtml(<img src="/resources/{kind_to_string(piece.kind)}_{colorc_to_string(piece.color)}.png" />)
                    do Position.select_chess_position(pos) |> Dom.put_inside(_,img)
                    void
                ,pos.piece)
            ,_)
        ,_)
        void

    update(board: board) =  
        place_pieces(board)
        

    piece_at(row,column,board): option(chess_position) =
        column_letter = Column.from_int(column+64)
        user_color = Option.get(Game.get_state()).color
        Map.get(column_letter, board.chess_positions) |> Option.get(_) |> Map.get(row, _) |> Option.get(_) |> pos ->
            match pos with 
                | { piece = { some = {color = color kind = kind}} ...} -> if color == user_color then { some = pos } else {none}
                | _ -> {none}
        
    add_on_click_events(row,column,td,board: board): void = 
        do Dom.bind(td, {click}, (_ -> 
            
            name = Option.get(Game.get_state()).game
            user_color = Option.get(Game.get_state()).color
            next_color = match user_color with 
                | {white} -> {black}
                | {black} -> {white}
            movable = piece_at(row,column,board)

            if Option.is_some(movable) then 
                pos = Option.get(movable)
                do Dom.select_raw("td.movable")  |> Dom.remove_class(_,"movable")
                do Dom.select_raw("td.selected") |> Dom.remove_class(_,"selected")
                do Dom.add_class(td, "selected")
                highlight_possible_movements(pos, Option.get(pos.piece))
            else if Dom.has_class(td,"movable") then 
                posFrom  = Dom.select_raw("td.selected") |> Position.chess_position_from_dom(_, board)
                posTo    = Position.chess_position_from_dom(td, board)
                newBoard = move(posFrom, posTo, board)
                channel  = Option.get(Game.get_state()).channel
                do Dom.select_raw("td.movable")  |> Dom.remove_class(_,"movable")
                do Dom.select_raw("td.selected") |> Dom.remove_class(_,"selected")
                do Network.broadcast({ state = newBoard turn = next_color},channel) 
                void
            else 
                void
        ))
        void
    
    highlight_possible_movements(pos: chess_position, piece: piece): void = 
        user_color = Option.get(Game.get_state()).color
        do Position.movable_chess_positions(pos,piece,user_color) |> List.iter(pos -> 
            movable = Position.select_chess_position(pos)
            Dom.add_class(movable,"movable")
        ,_)
        void
            
    labelize(row,column,td,board): void = 
        Dom.add_class(td, Column.from_int(column+64) ^ Int.to_string(row)) 
    
    colorize(row,column,td,board): void = 
        if (mod(row,2) == 0) then 
            if mod(column,2) == 0 then Dom.add_class(td, "black") else Dom.add_class(td, "white") 
        else 
            if mod(column,2) == 0 then Dom.add_class(td, "white") else Dom.add_class(td, "black")

    move(posFrom, posTo, board): board = 
        // remove the old piece
        chess_positions = Map.replace(posFrom.letter, rows -> (
            Map.replace(posFrom.number, (oldPos -> { oldPos with piece = {none}}), rows)
        ), board.chess_positions)
        // place the new piece 
        chess_positions2 = Map.replace(posTo.letter, rows -> (
            Map.replace(posTo.number, (oldPos -> { oldPos with piece = posFrom.piece}), rows)
        ), chess_positions)
        { board with chess_positions = chess_positions2}
        
    
    create() = { chess_positions = 
        columns = ["A","B","C","D","E","F","G","H"] 
        rows = duplicate(8,[8,7,6,5,4,3,2,1])
        List.map( column -> (column, 
            List.map( row -> (row, 
                pos = { letter = column number = row piece = {none}}
                match (column, row) with
                    | ("A",8) -> {pos with piece = some({ kind = {rook}   color = {black} })}
                    | ("B",8) -> {pos with piece = some({ kind = {knight} color = {black} })}
                    | ("C",8) -> {pos with piece = some({ kind = {bishop} color = {black} })}
                    | ("D",8) -> {pos with piece = some({ kind = {king}   color = {black} })}
                    | ("E",8) -> {pos with piece = some({ kind = {queen}  color = {black} })}
                    | ("F",8) -> {pos with piece = some({ kind = {bishop} color = {black} })}
                    | ("G",8) -> {pos with piece = some({ kind = {knight} color = {black} })}
                    | ("H",8) -> {pos with piece = some({ kind = {rook}   color = {black} })}
                    | (_,7)   -> {pos with piece = some({ kind = {pawn}   color = {black} })}
                    | (_,2)   -> {pos with piece = some({ kind = {pawn}   color = {white} })}
                    | ("A",1) -> {pos with piece = some({ kind = {rook}   color = {white} })}
                    | ("B",1) -> {pos with piece = some({ kind = {knight} color = {white} })}
                    | ("C",1) -> {pos with piece = some({ kind = {bishop} color = {white} })}
                    | ("D",1) -> {pos with piece = some({ kind = {king}   color = {white} })}
                    | ("E",1) -> {pos with piece = some({ kind = {queen}  color = {white} })}
                    | ("F",1) -> {pos with piece = some({ kind = {bishop} color = {white} })}
                    | ("G",1) -> {pos with piece = some({ kind = {knight} color = {white} })}
                    | ("H",1) -> {pos with piece = some({ kind = {rook}   color = {white} })}
                    | (_,_)   -> pos
            ),rows) |> create_int_map(_)
        ),columns) |> create_string_map(_)
    }
}}

/*
    {Position module}
*/

Position = {{

    chess_position_from_dom(dom: dom, board): chess_position = 
        // Very hacky. The 7th and 8th chars are the colulm and row number.
        clz    = Dom.get_property(dom,"class") |> Option.get(_)
        column = String.get(6, clz)
        row    = String.get(7, clz) |> String.to_int(_)
        Map.get(column, board.chess_positions) |> Option.get(_) |> Map.get(row, _) |> Option.get(_)

    select_chess_position(pos: chess_position): dom = 
        Dom.select_raw("." ^ pos.letter ^ Int.to_string(pos.number))
        
    movable_chess_positions(pos: chess_position, piece: piece, user_color: colorC): list(chess_position) = (
        xs = match piece.kind with
            | {king}   -> 
                [right(pos,1),left(pos,1),up(pos,1),down(pos,1),
                 right(pos,1) |> Option.bind( p -> up(p,1) ,_),
                 right(pos,1) |> Option.bind( p -> down(p,1) ,_),
                 left(pos,1) |> Option.bind( p -> up(p,1) ,_),
                 left(pos,1) |> Option.bind( p -> down(p,1) ,_)]
            | {queen}  -> 
                (diagonal({left_up},pos)  ++ diagonal({left_down},pos) ++ 
                 diagonal({right_up},pos) ++ diagonal({right_down},pos) ++
                 right_inclusive(pos,7)   ++ left_inclusive(pos,7) ++
                 up_inclusive(pos,7)      ++ down_inclusive(pos,7)) |> 
                List.map( x -> { some = x}, _)
            | {rook}   ->
                List.flatten([
                    right_inclusive(pos,7),
                    left_inclusive(pos,7),
                    up_inclusive(pos,7),
                    down_inclusive(pos,7)]) |> 
                List.map( x -> { some = x}, _)
            | {bishop} -> 
                List.flatten([
                    diagonal({left_up},pos),
                    diagonal({left_down},pos),
                    diagonal({right_up},pos),
                    diagonal({right_down},pos)]) |> 
                List.map( x -> { some = x}, _)
            | {knight} -> 
                [right(pos,1) |> Option.bind( p -> down(p,2),_),
                 right(pos,1) |> Option.bind( p -> up(p,2),_),
                 left(pos,1) |> Option.bind(p -> down(p,2),_),
                 left(pos,1) |> Option.bind(p -> up(p,2),_),
                 up(pos,1) |> Option.bind( p -> left(p,2),_),
                 up(pos,1) |> Option.bind( p -> right(p,2),_),
                 down(pos,1) |> Option.bind(p -> left(p,2),_),
                 down(pos,1) |> Option.bind(p -> right(p,2),_)]
            | {pawn}   -> 
                if user_color == {white} then
                    if pos.number == 2 then
                        up_inclusive(pos,2) |> List.map( x -> { some = x}, _)
                    else
                        [up(pos,1)]
                else 
                    if pos.number == 7 then
                        down_inclusive(pos,2) |> List.map( x -> { some = x}, _)
                    else
                        [down(pos,1)]                    
        List.filter_map( x -> x , xs)
    )
    /*
        Helper functions. 
    */
    
    right(pos,i): option(chess_position) = 
        x = Column.to_int(pos.letter)
        l = Column.from_int(x+i)
        if (x+i) > 72 then {none} else {some = {pos with letter = l}}
    
    left(pos,i): option(chess_position) = 
        x = Column.to_int(pos.letter)
        l = Column.from_int(x-i)
        if (x-i) < 65 then {none} else {some = {pos with letter = l}}
            
    up(pos,i): option(chess_position) =             
        if (pos.number + i) > 8 then {none} else {some = {pos with number = pos.number+i}}
                                                     
    down(pos,i): option(chess_position) =        
        if (pos.number - i) < 1 then {none} else {some = {pos with number = pos.number-i}}

    right_inclusive(pos: chess_position,i: int): list(chess_position) =
        rec r(pos,i,acc) = match i with
            | 0 -> acc
            | x -> match right(pos,1) with
                | {none} -> acc // fail fast. can't jump over 
                | {some = p} -> r(p,i-1,[p|acc])
        r(pos,i,[])

    left_inclusive(pos: chess_position,i: int): list(chess_position) =
        rec r(pos,i,acc) = match i with
            | 0 -> acc
            | x -> match left(pos,1) with
                | {none} -> acc // fail fast. can't jump over 
                | {some = p} -> r(p,i+1,[p|acc])
        r(pos,i,[])

    up_inclusive(pos: chess_position,i: int): list(chess_position) =
        rec r(pos,i,acc) = match i with
            | 0 -> acc
            | x -> match up(pos,1) with
                | {none} -> acc // fail fast. can't jump over 
                | {some = p} -> r(p,i-1,[p|acc])
        r(pos,i,[])
        
    down_inclusive(pos: chess_position,i: int): list(chess_position) =
        rec r(pos,i,acc) = match i with
            | 0 -> acc
            | x -> match down(pos,1) with
                | {none} -> acc // fail fast. can't jump over 
                | {some = p} -> r(p,i+1,[p|acc])
        r(pos,i,[])

    diagonal(direction: direction, pos: chess_position): list(chess_position) = 
        rec r(pos: chess_position,i,acc) = match i with
            | 0 -> acc
            | x -> 
                p = match direction with
                    | {left_up}    -> up(pos,1) |> Option.bind( p -> left(p,1),_)
                    | {left_down}  -> down(pos,1) |> Option.bind( p-> left(p,1),_)
                    | {right_up}   -> up(pos,1) |> Option.bind( p -> right(p,1),_) 
                    | {right_down} -> down(pos,1) |> Option.bind( p -> left(p,1),_)
                match p with 
                    | {none} -> acc
                    | {some = p} -> r(p,i-1,[p|acc])
        r(pos,7,[])
}}