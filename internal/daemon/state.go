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
	OwnerToken      string `json:"owner_token,omitempty"`
}

type ToolsListResponse struct {
	Daemon          bool     `json:"daemon"`
	PluginConnected bool     `json:"plugin_connected"`
	Project         string   `json:"project,omitempty"`
	Tools           []string `json:"tools"`
	OwnerToken      string   `json:"owner_token,omitempty"`
}

type connectionState struct {
	mu              sync.RWMutex
	pluginConnected bool
	project         string
	tools           []string
	ownerToken      string
	stopFn          context.CancelFunc
}

func newConnectionState(ownerToken string) *connectionState {
	return &connectionState{ownerToken: ownerToken}
}

func (s *connectionState) SetConnected(project string, tools []string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pluginConnected = true
	s.project = project
	s.tools = cloneStrings(tools)
}

func (s *connectionState) SetDisconnected() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pluginConnected = false
	s.project = ""
	s.tools = nil
}

func (s *connectionState) Snapshot() StatusResponse {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return StatusResponse{
		Daemon:          true,
		PluginConnected: s.pluginConnected,
		Project:         s.project,
		OwnerToken:      s.ownerToken,
	}
}

func (s *connectionState) ToolsSnapshot() ToolsListResponse {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return ToolsListResponse{
		Daemon:          true,
		PluginConnected: s.pluginConnected,
		Project:         s.project,
		Tools:           cloneStrings(s.tools),
		OwnerToken:      s.ownerToken,
	}
}

func (s *connectionState) OwnerToken() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.ownerToken
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

func cloneStrings(items []string) []string {
	if len(items) == 0 {
		return []string{}
	}

	cloned := make([]string, len(items))
	copy(cloned, items)
	return cloned
}
