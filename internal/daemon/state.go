package daemon

import (
	"context"
	"sync"
	"time"
)

type StatusResponse struct {
	Daemon          bool   `json:"daemon"`
	PluginConnected bool   `json:"plugin_connected"`
	Project         string `json:"project,omitempty"`
}

type connectionState struct {
	mu              sync.RWMutex
	pluginConnected bool
	project         string
	stopFn          context.CancelFunc
}

func newConnectionState() *connectionState {
	return &connectionState{}
}

func (s *connectionState) SetConnected(project string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pluginConnected = true
	s.project = project
}

func (s *connectionState) SetDisconnected() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pluginConnected = false
	s.project = ""
}

func (s *connectionState) Snapshot() StatusResponse {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return StatusResponse{
		Daemon:          true,
		PluginConnected: s.pluginConnected,
		Project:         s.project,
	}
}

func (s *connectionState) SetStopFunc(stopFn context.CancelFunc) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.stopFn = stopFn
}

func (s *connectionState) Stop() {
	s.mu.RLock()
	stopFn := s.stopFn
	s.mu.RUnlock()

	if stopFn != nil {
		stopFn()
	}
}

func shutdownTimeout() time.Duration {
	return 5 * time.Second
}
