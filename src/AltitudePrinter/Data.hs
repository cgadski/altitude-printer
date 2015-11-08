{-|
Datatypes, as written by the server, with fast parsing functions.
-}
module AltitudePrinter.Data
    (
    ) where

import Text.JSON
import Data.List

{-------------------------------------------------------------------------------
* Server Event
-------------------------------------------------------------------------------}

type PlayerID = Int
type VaporID = String
type Nick = String

data Player = Player
  { getPlayerID :: PlayerID
  , getVaporID :: VaporID
  , getNick :: Nick } deriving (Show, Eq)

type Tourny = Bool

data ServerEvent =
  SessionStart String -- ^ date
  | ServerInit String Int -- ^ server name and max player count

data Event =
  ChatEvent PlayerID String  -- a player says something
  | JoinEvent Player -- a player starts entering the server
  | LeaveEvent Player -- a player leaves the server
  | MoveEvent PlayerID Int -- a player moves to a team
  deriving (Show, Eq)

eventFromLog  :: String -> Maybe Event
eventFromLog str =
  case decode str of
    Ok a -> parseJson a
    Error _ -> Nothing

parseJson :: JSValue -> Maybe Event
parseJson value =
  case value of
    (JSObject o) ->
      parseList (fromJSObject o)
    _ -> Nothing

stringFromValue :: JSValue -> Maybe String
stringFromValue val =
  case val of
    JSString str -> Just $ fromJSString str
    _ -> Nothing

intFromValue :: JSValue -> Maybe Int
intFromValue val =
  case val of
    JSRational _ num -> Just $ round num
    _ -> Nothing

boolFromValue :: JSValue -> Maybe Bool
boolFromValue val =
  case val of
    (JSBool x) -> Just x
    _ -> Nothing

listFromValue :: JSValue -> Maybe [JSValue]
listFromValue val =
  case val of
    (JSArray xs) -> Just xs
    _ -> Nothing

objectFromValue :: JSValue -> Maybe (JSObject JSValue)
objectFromValue val =
  case val of
    JSObject obj -> Just obj
    _ -> Nothing

type LogAttrs = [(String, JSValue)]

getAttr :: String -> LogAttrs -> Maybe JSValue
getAttr name attrs =
  case find ((== name) . fst) attrs of
    Just (_, val) -> Just val
    Nothing -> Nothing

attrType :: LogAttrs -> Maybe String
attrType attrs = stringFromValue =<< getAttr "type" attrs

parseList :: LogAttrs -> Maybe Event
parseList attrs =
  let
    attr = flip getAttr attrs
    getPlayerInfo = do
      player <- intFromValue =<< attr "player"
      vapor <- stringFromValue =<< attr "vaporId"
      nick <- stringFromValue =<< attr "nickname"
      return $ Player player vapor nick
  in
  case attrType attrs of
    Just "chat" -> do
      message <- stringFromValue =<< attr "message"
      player <- intFromValue =<< attr "player"
      return $ ChatEvent player message
    Just "clientAdd" -> JoinEvent <$> getPlayerInfo
    Just "clientRemove" -> LeaveEvent <$> getPlayerInfo
    Just "teamChange" -> do
      player <- intFromValue =<< attr "player"
      team <- intFromValue =<< attr "team"
      return $ MoveEvent player team
    _ -> Nothing