package daemon

import (
	"context"
	"fmt"
	"sync"
)

type Daemon struct {
	wsServer   *wsServer
	httpServer *httpServer
	state      *connectionState
	once       sync.Once
}

func New(wsAddr string, httpAddr string) *Daemon {
	state := newConnectionState()
	ws := newWSServer(wsAddr, state)
	return &Daemon{
		wsServer:   ws,
		httpServer: newHTTPServer(httpAddr, state, ws),
		state:      state,
	}
}

func (d *Daemon) Start(parent context.Context) error {
	ctx, cancel := context.WithCancel(parent)
	defer cancel()

	d.state.SetStopFunc(cancel)

	errCh := make(chan error, 2)

	go func() {
		errCh <- d.wsServer.Start()
	}()

	go func() {
		errCh <- d.httpServer.Start()
	}()

	select {
	case <-ctx.Done():
		d.shutdown()
		return nil
	case err := <-errCh:
		cancel()
		d.shutdown()
		return fmt.Errorf("daemon server error: %w", err)
	}
}

func (d *Daemon) shutdown() {
	d.once.Do(func() {
		d.httpServer.Shutdown()
		d.wsServer.Shutdown()
	})
}
