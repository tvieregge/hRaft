{-# LANGUAGE RecordWildCards #-}

module Lib where

import Control.Concurrent (threadDelay)
import Control.Distributed.Process
    ( DiedReason(..)
    , NodeId(..)
    , PortMonitorNotification(..)
    , Process
    , ProcessId(..)
    , monitorPort
    , processNodeId
    , register
    , sendPortId
    , spawnLocal
    )
import Control.Distributed.Process.Extras.Time (Delay(..))
import Control.Distributed.Process.ManagedProcess
    ( ActionHandler
    , CastHandler
    , ChannelHandler
    , InitResult(..)
    , ProcessDefinition(..)
    , UnhandledMessagePolicy(..)
    , defaultProcess
    , handleCast
    , handleInfo
    , handleRpcChan
    , serve
    )
import Control.Distributed.Process.ManagedProcess.Server (continue, replyChan)
import Control.Distributed.Process.Node
    ( initRemoteTable
    , newLocalNode
    , runProcess
    )
import Control.Monad (forM_, forever, void)
import Control.Monad.IO.Class (liftIO)
import qualified Data.Map as M (delete, elemAt, empty, filter, insert, member)
import Network.Transport.TCP (createTransport, defaultTCPParameters)

-- module Lib
--     ( someFunc
--     ) where
someFunc :: IO ()
someFunc = putStrLn "someFunc"
