// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import { ITasks, IERC20, Escrow } from "./ITasks.sol";
import { TasksEnsure } from "./TasksEnsure.sol";
import { TasksUtils } from "./TasksUtils.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

contract Tasks is Context, TasksEnsure, TasksUtils {
    /// @notice The incremental ID for tasks.
    uint256 private taskCounter;

    /// @notice Various statistics about total tasks.
    uint256 private openTasks;
    uint256 private takenTasks;
    uint256 private successfulTasks;

    /// @notice A mapping between task IDs and task information.
    mapping(uint256 => Task) internal tasks;

    /// @notice The base escrow contract that will be cloned for every task.
    address private escrowImplementation;

    constructor() {
        escrowImplementation = address(new Escrow());
    }

    /// @inheritdoc ITasks
    function taskCount() external view returns (uint256) {
        return taskCounter;
    }
    
    /// @inheritdoc ITasks
    function taskStatistics() external view returns (uint256 open, uint256 taken, uint256 successful) {
        (open, taken, successful) = (openTasks, takenTasks, successfulTasks);
    }

    /// @inheritdoc ITasks
    function getTask(
        uint256 _taskId
    ) public view returns (OffChainTask memory offchainTask) {
        Task storage task = _getTask(_taskId);
        offchainTask = _toOffchainTask(task);
    }

    /// @inheritdoc ITasks
    function getTasks(
        uint256[] memory _taskIds
    ) public view returns (OffChainTask[] memory) {
        OffChainTask[] memory offchainTasks = new OffChainTask[](_taskIds.length);
        for (uint i; i < _taskIds.length; ) {
            offchainTasks[i] = getTask(_taskIds[i]);

            unchecked {
                ++i;
            }
        }
        return offchainTasks;
    }
    
    /// @inheritdoc ITasks
    function getManagingTasks(
        address _manager,
        uint256 _fromTaskId,
        uint256 _max
    ) external view returns (OffChainTask[] memory) {
        uint256 totalTasks = taskCounter;
        uint256[] memory taskIndexes = new uint256[](totalTasks);
        uint256 managerTasksCount;
        if (_fromTaskId == 0) {
            _fromTaskId = totalTasks - 1;
        }
        for (uint256 i = _fromTaskId; i != type(uint256).max; ) {
            if (tasks[i].manager == _manager) {
                taskIndexes[managerTasksCount] = i;
                unchecked {
                    ++managerTasksCount;
                }
                if (managerTasksCount == _max) {
                    // _max == 0 never triggering is on purpose
                    break;
                }
            }

            unchecked {
                --i;
            }
        }
        // decrease length of array to match real entries
        assembly { mstore(taskIndexes, sub(mload(taskIndexes), sub(totalTasks, managerTasksCount))) }
        return getTasks(taskIndexes);
    }
    
    /// @inheritdoc ITasks
    function getExecutingTasks(
        address _executor,
        uint256 _fromTaskId,
        uint256 _max
    ) external view returns (OffChainTask[] memory) {
        uint256 totalTasks = taskCounter;
        uint256[] memory taskIndexes = new uint256[](totalTasks);
        uint256 executorTasksCount;
        if (_fromTaskId == 0) {
            _fromTaskId = totalTasks - 1;
        }
        for (uint256 i = _fromTaskId; i != type(uint256).max; ) {
            if (tasks[i].state != TaskState.Open && tasks[i].applications[tasks[i].executorApplication].applicant == _executor) {
                taskIndexes[executorTasksCount] = i;
                unchecked {
                    ++executorTasksCount;
                }
                if (executorTasksCount == _max) {
                    // _max == 0 never triggering is on purpose
                    break;
                }
            }

            unchecked {
                --i;
            }
        }
        // decrease length of array to match real entries
        assembly { mstore(taskIndexes, sub(mload(taskIndexes), sub(totalTasks, executorTasksCount))) }
        return getTasks(taskIndexes);
    }

    /// @inheritdoc ITasks
    function createTask(
        string calldata _metadata,
        uint64 _deadline,
        ERC20Transfer[] calldata _budget,
        address _manager,
        PreapprovedApplication[] calldata _preapprove
    ) external returns (uint256 taskId) {
        taskId = taskCounter++;

        Task storage task = tasks[taskId];
        task.metadata = _metadata;
        task.deadline = _deadline;
        task.budgetCount = uint8(_budget.length);
        Escrow escrow = Escrow(Clones.clone(escrowImplementation));
        escrow.__Escrow_init();
        task.escrow = escrow;
        for (uint8 i; i < uint8(_budget.length); ) {
            _budget[i].tokenContract.transferFrom(_msgSender(), address(escrow), _budget[i].amount);
            task.budget[i] = _budget[i];
            unchecked {
                ++i;
            }
        }
        
        task.manager = _manager;
        task.creator = _msgSender();

        // Default values are already correct (save gas)
        // task.state = TaskState.Open;
        unchecked {
            // Impossible to overflow due to openTasks <= taskCounter
            ++openTasks;
        }

        // Gas optimization
        if (_preapprove.length > 0) {
            task.applicationCount = uint16(_preapprove.length);
            for (uint16 i; i < uint16(_preapprove.length); ) {
                Application storage application = task.applications[i];
                application.applicant = _preapprove[i].applicant;
                application.accepted = true;
                _setRewardBellowBudget(task, application, _preapprove[i].reward);

                unchecked {
                    ++i;
                }
            }
        }

        emit TaskCreated(taskId, _metadata, _deadline, _budget, _msgSender(), _manager, _preapprove);
    }

    /// @inheritdoc ITasks
    function applyForTask(
        uint256 _taskId,
        string calldata _metadata,
        Reward[] calldata _reward
    ) external returns (uint16 applicationId) {
        Task storage task = _getTask(_taskId);
        _ensureTaskIsOpen(task);

        Application storage application = task.applications[task.applicationCount];
        application.metadata = _metadata;
        application.applicant = _msgSender();
        application.rewardCount = uint8(_reward.length);
        for (uint8 i; i < uint8(_reward.length); ) {
            application.reward[i] = _reward[i];
            unchecked {
                ++i;
            }
        }

        applicationId = task.applicationCount++;

        emit ApplicationCreated(_taskId, applicationId, _metadata, _reward, task.manager, _msgSender());
    }
    
    /// @inheritdoc ITasks
    function acceptApplications(
        uint256 _taskId,
        uint16[] calldata _applicationIds
    ) external {
        Task storage task = _getTask(_taskId);
        _ensureTaskIsOpen(task);
        _ensureSenderIsManager(task);

        for (uint i; i < _applicationIds.length; ) {
            _ensureApplicationExists(task, _applicationIds[i]);
            
            Application storage application = task.applications[_applicationIds[i]];
            application.accepted = true;
            _increaseBudgetToReward(task, application.rewardCount, application.reward);
            emit ApplicationAccepted(_taskId, _applicationIds[i], _msgSender(), application.applicant);
            
            unchecked {
                ++i;
            }
        }
    }
    
    /// @inheritdoc ITasks
    function takeTask(
        uint256 _taskId,
        uint16 _applicationId
    ) external {
        Task storage task = _getTask(_taskId);
        _ensureTaskIsOpen(task);
        _ensureApplicationExists(task, _applicationId);

        Application storage application = task.applications[_applicationId];
        _ensureSenderIsApplicant(application);
        _ensureApplicationIsAccepted(application);

        task.executorApplication = _applicationId;

        task.state = TaskState.Taken;
        unchecked {
            --openTasks;
            ++takenTasks;
        }

        emit TaskTaken(_taskId, _applicationId, task.manager, _msgSender());
    }
    
    /// @inheritdoc ITasks
    function createSubmission(
        uint256 _taskId,
        string calldata _metadata
    ) external returns (uint8 submissionId) {
        Task storage task = _getTask(_taskId);
        _ensureTaskIsTaken(task);
        _ensureSenderIsExecutor(task);

        Submission storage submission = task.submissions[task.submissionCount];
        submission.metadata = _metadata;
        submissionId = task.submissionCount++;

        emit SubmissionCreated(_taskId, submissionId, _metadata, task.manager, _msgSender());
    }
    
    /// @inheritdoc ITasks
    function reviewSubmission(
        uint256 _taskId,
        uint8 _submissionId,
        SubmissionJudgement _judgement,
        string calldata _feedback
    ) external {
        Task storage task = _getTask(_taskId);
        _ensureTaskIsTaken(task);
        _ensureSenderIsManager(task);
        _ensureSubmissionExists(task, _submissionId);

        Submission storage submission = task.submissions[_submissionId];
        _ensureSubmissionNotJudged(submission);
        submission.judgement = _judgement;
        submission.feedback = _feedback;

        if (_judgement == SubmissionJudgement.Accepted) {
            _payoutTask(task);
            unchecked {
                --takenTasks;
                ++successfulTasks;
            }

            emit TaskCompleted(_taskId, _msgSender(), task.applications[task.executorApplication].applicant);
        }

        emit SubmissionReviewed(_taskId, _submissionId, _judgement, _feedback, _msgSender(), task.applications[task.executorApplication].applicant);
    }

    /// @inheritdoc ITasks
    function cancelTask(
        uint256 _taskId,
        string calldata _explanation
    ) external returns (uint8 cancelTaskRequestId) {
        Task storage task = _getTask(_taskId);
        _ensureSenderIsManager(task);

        _ensureTaskNotClosed(task);

        if (task.state == TaskState.Open || task.deadline <= uint64(block.timestamp)) {
            // Task is open or deadline past
            _refundCreator(task);
            if (task.state == TaskState.Open) {
                unchecked {
                    --openTasks;
                }
            } else if (task.state == TaskState.Taken) {
                unchecked {
                    --takenTasks;
                }
            }
            emit TaskCancelled(_taskId, _msgSender(), task.state == TaskState.Open ? address(0) : task.applications[task.executorApplication].applicant);
            // Max means no request
            cancelTaskRequestId = type(uint8).max;
        }
        else {
            // Task is taken and deadline has not past
            CancelTaskRequest storage request = task.cancelTaskRequests[task.cancelTaskRequestCount];
            request.explanation = _explanation;
            cancelTaskRequestId = task.cancelTaskRequestCount++;

            emit CancelTaskRequested(_taskId, cancelTaskRequestId, _explanation, _msgSender(), task.applications[task.executorApplication].applicant);
        }
    }

    /// @inheritdoc ITasks
    function acceptRequest(
        uint256 _taskId,
        RequestType _requestType,
        uint8 _requestId,
        bool _execute
    ) external {
        Task storage task = _getTask(_taskId);
        _ensureTaskIsTaken(task);
        _ensureSenderIsExecutor(task);
        
        if (_requestType == RequestType.CancelTask) {
            _ensureCancelTaskRequestExists(task, _requestId);
            
            CancelTaskRequest storage cancelTaskRequest = task.cancelTaskRequests[_requestId];
            _ensureRequestNotAccepted(cancelTaskRequest.request);

            if (_execute) {
                // use executeRequest in the body instead? (more gas due to all the checks, but less code duplication)
                _refundCreator(task);
                unchecked {
                    --takenTasks;
                }
                emit TaskCancelled(_taskId, task.manager, _msgSender());
                cancelTaskRequest.request.executed = true;
            }

            cancelTaskRequest.request.accepted = true;
        }

        emit RequestAccepted(_taskId, _requestType, _requestId, task.manager, _msgSender());
    }

    /// @inheritdoc ITasks
    function executeRequest(
        uint256 _taskId,
        RequestType _requestType,
        uint8 _requestId
    ) external {
        Task storage task = _getTask(_taskId);
        _ensureTaskIsTaken(task);
        
        if (_requestType == RequestType.CancelTask) {
            _ensureCancelTaskRequestExists(task, _requestId);
            
            CancelTaskRequest storage cancelTaskRequest = task.cancelTaskRequests[_requestId];
            _ensureRequestAccepted(cancelTaskRequest.request);
            _ensureRequestNotExecuted(cancelTaskRequest.request);

            _refundCreator(task);
            unchecked {
                --takenTasks;
            }
            emit TaskCancelled(_taskId, task.manager, task.applications[task.executorApplication].applicant);
            cancelTaskRequest.request.executed = true;
        }

        emit RequestExecuted(_taskId, _requestType, _requestId, _msgSender(), task.manager, task.applications[task.executorApplication].applicant);
    }

    /// @inheritdoc ITasks
    function extendDeadline(
        uint256 _taskId,
        uint64 _extension
    ) external {
        Task storage task = _getTask(_taskId);
        _ensureSenderIsManager(task);

        _ensureTaskNotClosed(task);

        task.deadline += _extension;

        emit DeadlineExtended(_taskId, _extension, _msgSender(), task.state == TaskState.Open ? address(0) : task.applications[task.executorApplication].applicant);
    }

    /// @inheritdoc ITasks
    function increaseBudget(
        uint256 _taskId,
        uint96[] calldata _increase
    ) external {
        Task storage task = _getTask(_taskId);
        _ensureSenderIsManager(task);

        _ensureTaskIsOpen(task);

        for (uint8 i; i < uint8(_increase.length); ) {
            ERC20Transfer storage transfer = task.budget[i];
            transfer.tokenContract.transferFrom(_msgSender(), address(task.escrow), _increase[i]);
            transfer.amount += _increase[i];

            unchecked {
                ++i;
            }
        }

        emit BudgetIncreased(_taskId, _increase, _msgSender());
    }

    /// @inheritdoc ITasks
    function editMetadata(
        uint256 _taskId,
        string calldata _newMetadata
    ) external {
        Task storage task = _getTask(_taskId);
        _ensureSenderIsManager(task);

        _ensureTaskIsOpen(task);

        task.metadata = _newMetadata;
        emit MetadataEditted(_taskId, _newMetadata, _msgSender());
    }

    function _getTask(uint256 _taskId) internal view returns (Task storage task) {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }

        task = tasks[_taskId];
    }
}