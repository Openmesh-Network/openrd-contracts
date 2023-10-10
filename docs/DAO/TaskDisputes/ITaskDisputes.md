# ITaskDisputes









## Methods

### createDispute

```solidity
function createDispute(bytes _metadata, uint64 _startDate, uint64 _endDate, uint256 _taskId, uint88[] _partialReward, uint96[] _partialNativeReward) external payable
```

Create a dispute for a task



#### Parameters

| Name | Type | Description |
|---|---|---|
| _metadata | bytes | Metadata of the proposal. |
| _startDate | uint64 | Start date of the proposal. |
| _endDate | uint64 | End date of the proposal. |
| _taskId | uint256 | The task wanting to complete by dispute. |
| _partialReward | uint88[] | Complete with how much of the reward. |
| _partialNativeReward | uint96[] | Complete with how much of the native reward. |

### getDisputeCost

```solidity
function getDisputeCost() external view returns (uint256)
```

The minimum amount of native currency that has to be attached to create a dispute.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getGovernanceContract

```solidity
function getGovernanceContract() external view returns (contract IPluginProposals)
```

The governance plugin (instance) contract where proposals are created.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IPluginProposals | undefined |

### getTasksContract

```solidity
function getTasksContract() external view returns (contract ITasks)
```

The Tasks contract where tasks are created.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ITasks | undefined |

### updateDisputeCost

```solidity
function updateDisputeCost(uint256 _disputeCost) external nonpayable
```

Updates the dispute cost.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _disputeCost | uint256 | The new dispute cost. |

### updateGovernanceContract

```solidity
function updateGovernanceContract(contract IPluginProposals _governancePlugin) external nonpayable
```

Updates the governance plugin contract address.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _governancePlugin | contract IPluginProposals | The new governance plugin contract address. |

### updateTasksContract

```solidity
function updateTasksContract(contract ITasks _tasks) external nonpayable
```

Updates the tasks contract address.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tasks | contract ITasks | The new Tasks contract address. |




## Errors

### TransferToDAOError

```solidity
error TransferToDAOError()
```






### Underpaying

```solidity
error Underpaying()
```






