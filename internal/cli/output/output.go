package output

import (
	"encoding/json"
	"fmt"
	"io"

	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
)

type Result struct {
	Command string
	Text    string
	Data    any
}

type Presenter interface {
	Success(result Result) error
	Failure(command string, err error) error
}

type jsonEnvelope struct {
	OK      bool           `json:"ok"`
	Code    int            `json:"code"`
	Command string         `json:"command"`
	Data    any            `json:"data,omitempty"`
	Error   *envelopeError `json:"error,omitempty"`
}

type envelopeError struct {
	Type    string `json:"type"`
	Message string `json:"message"`
}

func NewPresenter(jsonMode bool, stdout io.Writer, stderr io.Writer) Presenter {
	if jsonMode {
		return &jsonPresenter{stdout: stdout}
	}
	return &textPresenter{stdout: stdout, stderr: stderr}
}

type textPresenter struct {
	stdout io.Writer
	stderr io.Writer
}

func (p *textPresenter) Success(result Result) error {
	if result.Text == "" {
		return nil
	}
	_, err := fmt.Fprintln(p.stdout, result.Text)
	return err
}

func (p *textPresenter) Failure(_ string, err error) error {
	_, writeErr := fmt.Fprintln(p.stderr, err)
	if writeErr != nil {
		return writeErr
	}
	return nil
}

type jsonPresenter struct {
	stdout io.Writer
}

func (p *jsonPresenter) Success(result Result) error {
	envelope := jsonEnvelope{
		OK:      true,
		Code:    clierrors.CodeSuccess,
		Command: result.Command,
		Data:    result.Data,
	}
	return json.NewEncoder(p.stdout).Encode(envelope)
}

func (p *jsonPresenter) Failure(command string, err error) error {
	envelope := jsonEnvelope{
		OK:      false,
		Code:    clierrors.ExitCode(err),
		Command: command,
		Error: &envelopeError{
			Type:    string(clierrors.KindOf(err)),
			Message: err.Error(),
		},
	}
	return json.NewEncoder(p.stdout).Encode(envelope)
}
