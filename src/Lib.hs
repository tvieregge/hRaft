module Lib where

import Control.Monad (replicateM)
import Control.Concurrent (threadDelay)
import Control.Monad (forever)
import Control.Distributed.Process
import Control.Distributed.Process.Node (runProcess, forkProcess, initRemoteTable, closeLocalNode)
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Control.Distributed.Process.Backend.SimpleLocalnet

replyBack :: (ProcessId, String) -> Process ()
replyBack (sender, msg) = send sender msg

logMessage :: String -> Process ()
logMessage msg = say $ "handling " ++ msg

echo = do
    receiveWait [match logMessage, match replyBack]

mainLoop selfPid backend = do
    peers <- liftIO $ findPeers backend 1000000
    liftIO . print $ show peers
    mapM_ (\x -> nsendRemote x "main" "sending message")
        $ filter (\x -> x /= (processNodeId selfPid)) peers
    received <- receiveTimeout (5 * 1000 * 1000) [match logMessage]
    mainLoop selfPid backend

someFunc :: IO ()
someFunc = do
    -- Right t <- createTransport "127.0.0.1" "10501" (\p -> ("","")) defaultTCPParameters
    backend <- initializeBackend "127.0.0.1" "10540" initRemoteTable
    -- nodes <- replicateM 3 $ newLocalNode backend
    node <- newLocalNode backend
    -- remotes <- mapM (flip forkProcess echo) nodes
    runProcess node $ do
        selfPid <- getSelfPid
        register "main" selfPid
        mainLoop selfPid backend
        return ()
