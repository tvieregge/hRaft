module Lib where

import Control.Monad (replicateM)
import Control.Concurrent (threadDelay)
import Control.Monad (forever)
import Control.Distributed.Process
import Control.Distributed.Process.Node (runProcess, forkProcess, initRemoteTable, closeLocalNode)
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Control.Distributed.Process.Backend.SimpleLocalnet

import Types

-- replyBack :: (ProcessId, String) -> Process ()
-- replyBack (sender, msg) = send sender msg

logMessage :: String -> Process ()
logMessage msg = say $ "handling " ++ msg

-- echo = do
--     receiveWait [match logMessage, match replyBack]

-- An implicit state machine, doesn't protect against calling into bad states.
-- TODO: Use types to enforce proper state transitions
runRaft :: RaftState -> RaftEvent -> Process RaftState
runRaft (Follower stateInfo) HeartBeat = followerLoop stateInfo
runRaft (Candidate stateInfo) Timeout = candidateLoop stateInfo

candidateLoop :: RaftStateInfo -> Process RaftState
candidateLoop state@(RaftStateInfo selfPid backend) = do
    say "Unimplimented state"
    runRaft (Follower state) HeartBeat

followerLoop :: RaftStateInfo -> Process RaftState
followerLoop state@(RaftStateInfo selfPid backend) = do
    peers <- liftIO $ findPeers backend 1000000
    let otherPeers = filter (\x -> x /= (processNodeId selfPid)) peers
    liftIO . print $ show otherPeers
    mapM_ (\x -> nsendRemote x "main" "sending message") otherPeers
    received <- receiveTimeout (5 * 1000 * 1000) [match logMessage]
    case received of
         Just msg -> followerLoop state
         Nothing -> runRaft (Candidate state) Timeout

someFunc :: IO ()
someFunc = do
    -- Right t <- createTransport "127.0.0.1" "10501" (\p -> ("","")) defaultTCPParameters
    backend <- initializeBackend "127.0.0.1" "10545" initRemoteTable
    -- nodes <- replicateM 3 $ newLocalNode backend
    node <- newLocalNode backend
    -- remotes <- mapM (flip forkProcess echo) nodes
    runProcess node $ do
        selfPid <- getSelfPid
        register "main" selfPid
        runRaft (Follower (RaftStateInfo selfPid backend)) HeartBeat
        return ()
