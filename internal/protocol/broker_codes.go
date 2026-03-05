package protocol

type BrokerErrorCode string

const (
	BrokerErrorCodeValidation         BrokerErrorCode = "validation_error"
	BrokerErrorCodePluginDisconnected BrokerErrorCode = "plugin_disconnected"
	BrokerErrorCodeTimeout            BrokerErrorCode = "timeout"
	BrokerErrorCodeCancelled          BrokerErrorCode = "cancelled"
	BrokerErrorCodeOperationFailed    BrokerErrorCode = "operation_failed"
)
