package daemon

import (
	"context"
	"fmt"
	"sync"

	"github.com/shanepadgett/godotctl/internal/daemon/httpserver"
	daemonstate "github.com/shanepadgett/godotctl/internal/daemon/state"
	"github.com/shanepadgett/godotctl/internal/daemon/ws"
)

type Daemon struct {
	wsServer   *ws.Server
	httpServer *httpserver.Server
	state      *daemonstate.Store
	once       sync.Once
}

func New(wsAddr string, httpAddr string, ownerToken string) *Daemon {
	state := daemonstate.New(ownerToken)
	wsServer := ws.New(wsAddr, state)
	return &Daemon{
		wsServer:   wsServer,
		httpServer: httpserver.New(httpAddr, state, wsServer),
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
