package shared

import (
	"fmt"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

type Deps struct {
	Client    *client.DaemonClient
	Presenter func() output.Presenter
	WSAddr    string
	HTTPAddr  string
}

func (d Deps) Success(result output.Result) error {
	presenter := d.presenter()
	if presenter == nil {
		return fmt.Errorf("presenter unavailable")
	}

	return presenter.Success(result)
}

func (d Deps) Fail(cmd *cobra.Command, err error) error {
	presenter := d.presenter()
	if presenter != nil {
		_ = presenter.Failure(cmd.CommandPath(), err)
	}

	return err
}

func (d Deps) presenter() output.Presenter {
	if d.Presenter == nil {
		return nil
	}

	return d.Presenter()
}
