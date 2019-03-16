{-# LANGUAGE GeneralizedNewtypeDeriving #-} -- Allows automatic derivation of e.g. Monad
{-# LANGUAGE DeriveGeneric              #-} -- Allows Generic, for auto-generation of serialization code

module Lib where

import Control.Distributed.Process (Process, ProcessId,
    send, say, expect, getSelfPid, spawnLocal, match, receiveWait)

import Data.Binary (Binary) -- Objects have to be binary to send over the network
import GHC.Generics (Generic) -- For auto-derivation of serialization
import Data.Typeable (Typeable) -- For safe serialization

import Control.Monad.RWS.Strict (
    RWS, MonadReader, MonadWriter, MonadState,
    ask, tell, get, put, execRWS, liftIO)
import Control.Monad (replicateM, forever)
import Control.Concurrent (threadDelay)
import Control.Lens (makeLenses, (+=), (%%=))

import System.Random (StdGen, Random, randomR, newStdGen)

data Message = Heartbeat {sender :: ProcessId, recipient :: ProcessId}
             | VoteRequest {sender :: ProcessId, recipient :: ProcessId}
             | VoteResponse {recipient :: ProcessId}
               deriving (Show, Generic, Typeable)

data Tick = Tick deriving (Show, Generic, Typeable)

data RaftState = Leader | Follower | Candidate
               deriving (Show, Generic, Typeable, Eq)

instance Binary RaftState
instance Binary Message
instance Binary Tick

-- TODO: Use lenses here
data ServerState = ServerState {
    raftState :: RaftState,
    randomGen :: StdGen,
    ticksSinceMsg :: Integer
} deriving (Show)

data ServerConfig = ServerConfig {
    myId  :: ProcessId,
    peers :: [ProcessId]
} deriving (Show)

newtype ServerAction a = ServerAction {runAction :: RWS ServerConfig [Message] ServerState a}
    deriving (Functor, Applicative, Monad, MonadState ServerState,
              MonadWriter [Message], MonadReader ServerConfig)

tickHandler :: Tick -> ServerAction ()
tickHandler Tick = do
    state@(ServerState raftState _ curTick) <- get
    put (state { ticksSinceMsg = curTick + 1})
    config <- ask
    case raftState of
         Leader -> tell $ sendHeartbeat (myId config) (peers config)
         Follower -> handleTickFollower
         Candidate -> return ()

handleTickFollower :: ServerAction ()
handleTickFollower = do
    state@(ServerState _ _ ticks) <- get
    if ticks >= 2
       then startElection
       else return ()

startElection :: ServerAction ()
startElection = do
    state <- get
    config <- ask
    put $ state { raftState = Candidate, ticksSinceMsg = 0 }
    tell $ sendInitiation (myId config) (peers config)

msgHandler :: Message -> ServerAction ()
msgHandler (Heartbeat sender recipient) = do
    state <- get
    put (state { ticksSinceMsg = 0 })
    return ()
msgHandler (VoteRequest sender _) = do
    state@(ServerState rState _ _) <- get
    put (state { ticksSinceMsg = 0 })
    case rState of
         Follower -> tell [VoteResponse sender]
         Candidate -> return ()
         Leader -> return ()

msgHandler (VoteResponse _) = do
    state <- get
    case raftState state of
         Follower -> return ()
         Candidate -> put (state {raftState = Leader}) -- only need one for now
         Leader -> return ()

sendInitiation :: ProcessId -> [ProcessId] -> [Message]
sendInitiation myId peers = do
    map (VoteRequest myId) peers

sendHeartbeat :: ProcessId -> [ProcessId] -> [Message]
sendHeartbeat myId peers = do
    map (Heartbeat myId) peers

runServer :: ServerConfig -> ServerState -> Process ()
runServer config state = do
    let run handler msg = return $ execRWS (runAction $ handler msg) config state
    (state', outputMessages) <- receiveWait [
            match $ run msgHandler,
            match $ run tickHandler]
    say $ show state' ++ " " ++ show outputMessages
    mapM (\msg -> send (recipient msg) msg) outputMessages
    runServer config state'

spawnServer :: Process ProcessId
spawnServer = spawnLocal $ do
    myPid <- getSelfPid
    otherPids <- fmap (filter (/= myPid)) expect
    randomGen <- liftIO newStdGen
    let random = fst $ randomR (10^6, 2*10^6) randomGen :: Int
    spawnLocal $ forever $ do
        liftIO $ threadDelay (random)
        send myPid Tick
    runServer (ServerConfig myPid otherPids) (ServerState Follower randomGen 0)

spawnServers :: Int -> Process ()
spawnServers count = do
    pids <- replicateM count spawnServer
    mapM_ (`send` pids) pids

