package state

import (
	"context"
	"sync"
	"time"

	"github.com/shanepadgett/godotctl/internal/protocol"
)

type Store struct {
	mu              sync.RWMutex
	pluginConnected bool
	project         string
	tools           []string
	pendingRequests int
	connectedSince  *time.Time
	ownerToken      string
	stopFn          context.CancelFunc
}

func New(ownerToken string) *Store {
	return &Store{ownerToken: ownerToken}
}

func (s *Store) SetConnected(project string, tools []string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.pluginConnected {
		now := time.Now().UTC()
		s.connectedSince = &now
	}
	s.pluginConnected = true
	s.project = project
	s.tools = cloneStrings(tools)
}

func (s *Store) SetDisconnected() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pluginConnected = false
	s.project = ""
	s.tools = nil
	s.pendingRequests = 0
	s.connectedSince = nil
}

func (s *Store) SetPendingRequests(n int) {
	if n < 0 {
		n = 0
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	s.pendingRequests = n
}

func (s *Store) Snapshot() protocol.StatusResponse {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var connectedSince *string
	if s.connectedSince != nil {
		formatted := s.connectedSince.Format(time.RFC3339)
		connectedSince = &formatted
	}

	return protocol.StatusResponse{
		Daemon:          true,
		PluginConnected: s.pluginConnected,
		Project:         s.project,
		PendingRequests: s.pendingRequests,
		ConnectedSince:  connectedSince,
		OwnerToken:      s.ownerToken,
	}
}

func (s *Store) ToolsSnapshot() protocol.ToolsListResponse {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return protocol.ToolsListResponse{
		Daemon:          true,
		PluginConnected: s.pluginConnected,
		Project:         s.project,
		Tools:           cloneStrings(s.tools),
		OwnerToken:      s.ownerToken,
	}
}

func (s *Store) OwnerToken() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.ownerToken
}

func (s *Store) SetStopFunc(stopFn context.CancelFunc) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.stopFn = stopFn
}

func (s *Store) Stop() {
	s.mu.RLock()
	stopFn := s.stopFn
	s.mu.RUnlock()

	if stopFn != nil {
		stopFn()
	}
}

func ShutdownTimeout() time.Duration {
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
