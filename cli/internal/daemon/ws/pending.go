package ws

func (s *Server) completePending(msg toolResultMessage) {
	ch, ok := s.removePending(msg.ID)
	if ok {
		ch <- pendingResult{result: msg}
	}
}

func (s *Server) addPending(requestID string, ch chan pendingResult) {
	s.pendingMu.Lock()
	defer s.pendingMu.Unlock()

	s.pending[requestID] = ch
	s.state.SetPendingRequests(len(s.pending))
}

func (s *Server) removePending(requestID string) (chan pendingResult, bool) {
	s.pendingMu.Lock()
	defer s.pendingMu.Unlock()

	ch, ok := s.pending[requestID]
	if ok {
		delete(s.pending, requestID)
		s.state.SetPendingRequests(len(s.pending))
	}

	return ch, ok
}

func (s *Server) failAllPending(err error) {
	s.pendingMu.Lock()
	defer s.pendingMu.Unlock()

	for id, ch := range s.pending {
		delete(s.pending, id)
		ch <- pendingResult{err: err}
	}
	s.state.SetPendingRequests(0)
}
