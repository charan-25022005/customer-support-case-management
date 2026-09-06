import { LightningElement, track, wire } from 'lwc';
import getCases from '@salesforce/apex/CaseService.getCases';
import getCaseDetails from '@salesforce/apex/CaseService.getCaseDetails';
import updateCaseStatus from '@salesforce/apex/CaseService.updateCaseStatus';
import getIntegrationLogs from '@salesforce/apex/CaseService.getIntegrationLogs';
import getCaseActivities from '@salesforce/apex/CaseService.getCaseActivities';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Case Number', fieldName: 'CaseNumber', type: 'text' },
    { label: 'Subject', fieldName: 'Subject', type: 'text' },
    { label: 'External ID', fieldName: 'External_Case_Id__c', type: 'text' },
    { label: 'Priority', fieldName: 'Priority', type: 'text' },
    { label: 'Status', fieldName: 'Status', type: 'text' },
    { label: 'VIP Customer', fieldName: 'Is_VIP__c', type: 'boolean' },
    { label: 'Owner', fieldName: 'OwnerName', type: 'text' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Details & Logs', name: 'view_details' },
                { label: 'Mark as Closed', name: 'close_case' },
                { label: 'Set to In Progress', name: 'working_case' }
            ]
        }
    }
];

export default class CaseManagement extends LightningElement {
    @track searchTerm = '';
    @track priorityFilter = 'ALL';
    @track statusFilter = 'ALL';
    @track cases = [];
    @track rawCases = [];
    @track isLoading = true;

    // Active Spotlight Case in 3x2 Grid
    @track activeCaseId = null;
    @track activeCase = null;
    @track activeLogs = [];
    @track formattedActiveLogs = [];
    @track activeActivities = [];
    @track formattedActiveActivities = [];
    @track isLoadingActive = false;

    // Modal State
    @track selectedCase = null;
    @track integrationLogs = [];
    @track formattedLogs = [];
    @track modalActivities = [];
    @track formattedModalActivities = [];
    @track isModalOpen = false;
    @track isCloseModalOpen = false;
    @track pendingCloseCaseId = null;
    @track resolutionSummaryInput = '';
    @track resolutionNotesInput = '';

    @track openMenuRowId = null;

    wiredCasesResult;
    columns = COLUMNS;

    priorityOptions = [
        { label: 'All Priorities', value: 'ALL' },
        { label: 'High', value: 'High' },
        { label: 'Medium', value: 'Medium' },
        { label: 'Low', value: 'Low' }
    ];

    statusOptions = [
        { label: 'All Statuses', value: 'ALL' },
        { label: 'New', value: 'New' },
        { label: 'Working', value: 'Working' },
        { label: 'Closed', value: 'Closed' }
    ];

    @wire(getCases, { searchTerm: '$searchTerm', priorityFilter: '$priorityFilter', statusFilter: '$statusFilter' })
    wiredCases(result) {
        this.wiredCasesResult = result;
        this.isLoading = true;
        if (result.data) {
            this.rawCases = result.data;
            this.cases = result.data.map(c => {
                const ownerName = c.Owner ? c.Owner.Name : 'Unassigned';
                const ownerInitials = this.getInitials(ownerName);
                const isVip = c.Is_VIP__c === true;
                const status = c.Status || 'New';
                const priority = c.Priority || 'Low';
                const isSelected = this.activeCaseId === c.Id;

                return {
                    ...c,
                    OwnerName: ownerName,
                    ownerInitials: ownerInitials,
                    isVip: isVip,
                    statusBadgeClass: this.getStatusBadgeClass(status),
                    priorityBadgeClass: this.getPriorityBadgeClass(priority),
                    isMenuOpen: this.openMenuRowId === c.Id,
                    rowClass: isSelected ? 'table-row-selected' : 'table-row'
                };
            });

            // Set initial active case if none selected or if active case no longer exists
            if (this.cases.length > 0) {
                const exists = this.cases.some(c => c.Id === this.activeCaseId);
                if (!this.activeCaseId || !exists) {
                    this.setActiveCase(this.cases[0].Id, this.cases[0].External_Case_Id__c);
                } else {
                    // Refresh current active case data
                    this.loadActiveCaseDetails(this.activeCaseId);
                }
            } else {
                this.activeCaseId = null;
                this.activeCase = null;
                this.activeLogs = [];
                this.formattedActiveLogs = [];
                this.activeActivities = [];
                this.formattedActiveActivities = [];
            }
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error loading cases', result.error.body ? result.error.body.message : 'Unknown error', 'error');
            this.isLoading = false;
        }
    }

    getInitials(name) {
        if (!name) return 'U';
        const parts = name.trim().split(' ');
        if (parts.length >= 2) {
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        }
        return name.substring(0, 2).toUpperCase();
    }

    getStatusBadgeClass(status) {
        if (!status) return 'pill-badge badge-status-new';
        const s = status.toLowerCase();
        if (s === 'closed') return 'pill-badge badge-status-closed';
        if (s === 'working' || s === 'in progress') return 'pill-badge badge-status-working';
        return 'pill-badge badge-status-new';
    }

    getPriorityBadgeClass(priority) {
        if (!priority) return 'pill-badge badge-priority-low';
        const p = priority.toLowerCase();
        if (p === 'high') return 'pill-badge badge-priority-high';
        if (p === 'medium') return 'pill-badge badge-priority-medium';
        return 'pill-badge badge-priority-low';
    }

    formatDate(rawDate) {
        if (!rawDate) return 'Not available';
        try {
            const dt = new Date(rawDate);
            return dt.toLocaleString('en-US', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            });
        } catch (e) {
            return rawDate;
        }
    }

    formatLogs(logs) {
        if (!logs) return [];
        return logs.map(log => {
            const isSuccess = log.Status__c === 'Success' || (log.Status_Code__c >= 200 && log.Status_Code__c < 300);
            return {
                ...log,
                isSuccess: isSuccess,
                iconName: isSuccess ? 'utility:check' : 'utility:error',
                timelineIconClass: isSuccess ? 'timeline-status-icon success' : 'timeline-status-icon error',
                timelineBadgeClass: isSuccess ? 'timeline-http-badge success' : 'timeline-http-badge error',
                statusBadgeText: isSuccess 
                    ? `✓ SUCCESS ${log.Status_Code__c ? '• HTTP ' + log.Status_Code__c : ''}` 
                    : `✕ FAILED ${log.Status_Code__c ? '• HTTP ' + log.Status_Code__c : ''}`,
                errorMessage: log.Error_Message__c,
                executionTime: log.Execution_Time_ms__c ? `${log.Execution_Time_ms__c}ms` : '0ms',
                formattedDate: this.formatDate(log.CreatedDate)
            };
        });
    }

    formatActivities(activities) {
        if (!activities) return [];
        return activities.map(act => {
            const isCompleted = act.Status === 'Completed';
            return {
                ...act,
                isCompleted: isCompleted,
                iconName: isCompleted ? 'utility:task2' : 'utility:clock',
                activityBadgeClass: isCompleted ? 'activity-badge completed' : 'activity-badge in-progress',
                ownerName: act.Owner ? act.Owner.Name : 'Support Agent',
                formattedDate: act.ActivityDate ? act.ActivityDate : this.formatDate(act.CreatedDate),
                descriptionText: act.Description ? act.Description : 'No activity details recorded.'
            };
        });
    }

    // Active Spotlight Case Helpers
    setActiveCase(caseId, externalCaseId) {
        this.activeCaseId = caseId;
        this.loadActiveCaseDetails(caseId, externalCaseId);
        this.updateCasesSelectionState();
    }

    loadActiveCaseDetails(caseId, externalCaseId) {
        if (!caseId) return;
        this.isLoadingActive = true;
        getCaseDetails({ caseId: caseId })
            .then(data => {
                this.activeCase = data;
                const extId = externalCaseId || (data ? data.External_Case_Id__c : null);
                return Promise.all([
                    extId ? getIntegrationLogs({ externalCaseId: extId }) : Promise.resolve([]),
                    getCaseActivities({ caseId: caseId })
                ]);
            })
            .then(([logs, activities]) => {
                this.activeLogs = logs || [];
                this.formattedActiveLogs = this.formatLogs(this.activeLogs);
                this.activeActivities = activities || [];
                this.formattedActiveActivities = this.formatActivities(this.activeActivities);
            })
            .catch(error => {
                console.error('Error loading active case details:', error);
            })
            .finally(() => {
                this.isLoadingActive = false;
            });
    }

    updateCasesSelectionState() {
        this.cases = this.cases.map(c => {
            return {
                ...c,
                rowClass: (c.Id === this.activeCaseId) ? 'table-row-selected' : 'table-row'
            };
        });
    }

    handleSelectCase(event) {
        const caseId = event.currentTarget.dataset.id;
        const externalId = event.currentTarget.dataset.externalid;
        if (caseId && caseId !== this.activeCaseId) {
            this.setActiveCase(caseId, externalId);
        }
    }

    // Active Case Getters
    get hasActiveCase() {
        return this.activeCase != null;
    }

    get activeCaseNumber() {
        return this.activeCase ? this.activeCase.CaseNumber : '';
    }

    get activeCaseSubject() {
        return this.activeCase ? this.activeCase.Subject : 'No Case Selected';
    }

    get activeCaseStatus() {
        return this.activeCase ? this.activeCase.Status : 'New';
    }

    get activeCasePriority() {
        return this.activeCase ? this.activeCase.Priority : 'Low';
    }

    get activeCaseIsVip() {
        return this.activeCase && this.activeCase.Is_VIP__c === true;
    }

    get activeCaseOwnerName() {
        return this.activeCase && this.activeCase.Owner ? this.activeCase.Owner.Name : 'Unassigned';
    }

    get activeCaseOwnerInitials() {
        return this.getInitials(this.activeCaseOwnerName);
    }

    get activeCaseExternalId() {
        return (this.activeCase && this.activeCase.External_Case_Id__c && this.activeCase.External_Case_Id__c.trim())
            ? this.activeCase.External_Case_Id__c
            : 'Not available';
    }

    get activeCaseDescription() {
        return (this.activeCase && this.activeCase.Description && this.activeCase.Description.trim())
            ? this.activeCase.Description
            : 'No description provided for this case.';
    }

    get activeCaseStatusBadgeClass() {
        return this.activeCase ? this.getStatusBadgeClass(this.activeCase.Status) : 'pill-badge badge-status-new';
    }

    get activeCasePriorityBadgeClass() {
        return this.activeCase ? this.getPriorityBadgeClass(this.activeCase.Priority) : 'pill-badge badge-priority-low';
    }

    get activeCaseIsClosed() {
        return this.activeCase && this.activeCase.Status === 'Closed';
    }

    get activeCaseResolutionSummary() {
        if (!this.activeCase) return 'Historical Case';
        return (this.activeCase.Resolution_Summary__c && this.activeCase.Resolution_Summary__c.trim())
            ? this.activeCase.Resolution_Summary__c
            : 'Historical Case';
    }

    get activeCaseResolutionNotes() {
        if (!this.activeCase) return 'Resolution details were not captured when this Case was originally closed.';
        return (this.activeCase.Resolution_Notes__c && this.activeCase.Resolution_Notes__c.trim())
            ? this.activeCase.Resolution_Notes__c
            : 'Resolution details were not captured when this Case was originally closed.';
    }

    get activeCaseResolvedByName() {
        if (!this.activeCase) return 'Not available';
        if (this.activeCase.Resolved_By__r && this.activeCase.Resolved_By__r.Name) {
            return this.activeCase.Resolved_By__r.Name;
        }
        if (this.activeCase.Owner && this.activeCase.Owner.Name) {
            return this.activeCase.Owner.Name;
        }
        return 'Not available';
    }

    get activeCaseResolvedDateFormatted() {
        if (!this.activeCase) return 'Not available';
        const rawDate = this.activeCase.Resolved_Date__c || this.activeCase.ClosedDate;
        return this.formatDate(rawDate);
    }

    get activeCaseCustomerId() {
        return (this.activeCase && this.activeCase.Customer_External_Id__c && this.activeCase.Customer_External_Id__c.trim())
            ? this.activeCase.Customer_External_Id__c
            : 'Not available';
    }

    get activeCaseCustomerName() {
        return (this.activeCase && this.activeCase.Contact && this.activeCase.Contact.Name && this.activeCase.Contact.Name.trim())
            ? this.activeCase.Contact.Name
            : 'Not available';
    }

    get activeCaseCustomerEmail() {
        return (this.activeCase && this.activeCase.Contact && this.activeCase.Contact.Email && this.activeCase.Contact.Email.trim())
            ? this.activeCase.Contact.Email
            : 'Not available';
    }

    get activeCaseCustomerPhone() {
        return (this.activeCase && this.activeCase.Contact && this.activeCase.Contact.Phone && this.activeCase.Contact.Phone.trim())
            ? this.activeCase.Contact.Phone
            : 'Not available';
    }

    get activeCaseAccountName() {
        return (this.activeCase && this.activeCase.Account && this.activeCase.Account.Name && this.activeCase.Account.Name.trim())
            ? this.activeCase.Account.Name
            : 'Not available';
    }

    get activeCaseCustomerType() {
        if (!this.activeCase) return 'Standard Customer';
        return this.activeCase.Is_VIP__c ? 'VIP Customer' : 'Standard Customer';
    }

    get hasActiveLogs() {
        return this.formattedActiveLogs && this.formattedActiveLogs.length > 0;
    }

    get hasActiveActivities() {
        return this.formattedActiveActivities && this.formattedActiveActivities.length > 0;
    }

    // Modal Specific Getters
    get isCaseClosed() {
        return this.selectedCase && this.selectedCase.Status === 'Closed';
    }

    get selectedCaseOwnerName() {
        return this.selectedCase && this.selectedCase.Owner ? this.selectedCase.Owner.Name : 'Unassigned';
    }

    get selectedCaseOwnerInitials() {
        return this.getInitials(this.selectedCaseOwnerName);
    }

    get selectedCaseExternalIdFormatted() {
        return (this.selectedCase && this.selectedCase.External_Case_Id__c && this.selectedCase.External_Case_Id__c.trim()) 
            ? this.selectedCase.External_Case_Id__c 
            : 'Not available';
    }

    get selectedCaseDescriptionFormatted() {
        return (this.selectedCase && this.selectedCase.Description && this.selectedCase.Description.trim()) 
            ? this.selectedCase.Description 
            : 'No description provided.';
    }

    get selectedCaseResolutionSummary() {
        if (!this.selectedCase) return 'Historical Case';
        return (this.selectedCase.Resolution_Summary__c && this.selectedCase.Resolution_Summary__c.trim())
            ? this.selectedCase.Resolution_Summary__c
            : 'Historical Case';
    }

    get selectedCaseResolutionNotes() {
        if (!this.selectedCase) return 'Resolution details were not captured when this Case was originally closed.';
        return (this.selectedCase.Resolution_Notes__c && this.selectedCase.Resolution_Notes__c.trim()) 
            ? this.selectedCase.Resolution_Notes__c 
            : 'Resolution details were not captured when this Case was originally closed.';
    }

    get selectedCaseResolvedByName() {
        if (!this.selectedCase) return 'Not available';
        if (this.selectedCase.Resolved_By__r && this.selectedCase.Resolved_By__r.Name) {
            return this.selectedCase.Resolved_By__r.Name;
        }
        if (this.selectedCase.Owner && this.selectedCase.Owner.Name) {
            return this.selectedCase.Owner.Name;
        }
        return 'Not available';
    }

    get selectedCaseResolvedDateFormatted() {
        if (!this.selectedCase) return 'Not available';
        const rawDate = this.selectedCase.Resolved_Date__c || this.selectedCase.ClosedDate;
        return this.formatDate(rawDate);
    }

    get selectedCaseStatusBadgeClass() {
        return this.selectedCase ? this.getStatusBadgeClass(this.selectedCase.Status) : 'pill-badge badge-status-new';
    }

    get selectedCasePriorityBadgeClass() {
        return this.selectedCase ? this.getPriorityBadgeClass(this.selectedCase.Priority) : 'pill-badge badge-priority-low';
    }

    get selectedCaseCustomerId() {
        return (this.selectedCase && this.selectedCase.Customer_External_Id__c && this.selectedCase.Customer_External_Id__c.trim())
            ? this.selectedCase.Customer_External_Id__c
            : 'Not available';
    }

    get selectedCaseCustomerName() {
        return (this.selectedCase && this.selectedCase.Contact && this.selectedCase.Contact.Name && this.selectedCase.Contact.Name.trim())
            ? this.selectedCase.Contact.Name
            : 'Not available';
    }

    get selectedCaseCustomerEmail() {
        return (this.selectedCase && this.selectedCase.Contact && this.selectedCase.Contact.Email && this.selectedCase.Contact.Email.trim())
            ? this.selectedCase.Contact.Email
            : 'Not available';
    }

    get selectedCaseCustomerPhone() {
        return (this.selectedCase && this.selectedCase.Contact && this.selectedCase.Contact.Phone && this.selectedCase.Contact.Phone.trim())
            ? this.selectedCase.Contact.Phone
            : 'Not available';
    }

    get selectedCaseAccountName() {
        return (this.selectedCase && this.selectedCase.Account && this.selectedCase.Account.Name && this.selectedCase.Account.Name.trim())
            ? this.selectedCase.Account.Name
            : 'Not available';
    }

    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    get hasLogs() {
        return this.formattedLogs && this.formattedLogs.length > 0;
    }

    get hasModalActivities() {
        return this.formattedModalActivities && this.formattedModalActivities.length > 0;
    }

    // 5 KPI Metrics
    get metrics() {
        const total = this.rawCases.length;
        const open = this.rawCases.filter(c => c.Status !== 'Closed').length;
        const closed = this.rawCases.filter(c => c.Status === 'Closed').length;
        const highPriority = this.rawCases.filter(c => c.Priority === 'High').length;
        const vip = this.rawCases.filter(c => c.Is_VIP__c === true).length;
        return { total, open, closed, highPriority, vip };
    }

    // Panel 6 Reporting & Distribution Metrics
    get priorityDistribution() {
        const total = this.rawCases.length || 1;
        const highCount = this.rawCases.filter(c => c.Priority === 'High').length;
        const mediumCount = this.rawCases.filter(c => c.Priority === 'Medium').length;
        const lowCount = this.rawCases.filter(c => c.Priority === 'Low' || !c.Priority).length;

        const highPercent = Math.round((highCount / total) * 100);
        const mediumPercent = Math.round((mediumCount / total) * 100);
        const lowPercent = Math.round((lowCount / total) * 100);

        return {
            highCount,
            highPercent,
            highStyle: `width: ${highPercent}%`,
            mediumCount,
            mediumPercent,
            mediumStyle: `width: ${mediumPercent}%`,
            lowCount,
            lowPercent,
            lowStyle: `width: ${lowPercent}%`
        };
    }

    get statusDistribution() {
        const total = this.rawCases.length || 1;
        const newCount = this.rawCases.filter(c => c.Status === 'New' || !c.Status).length;
        const workingCount = this.rawCases.filter(c => c.Status === 'Working' || c.Status === 'In Progress').length;
        const closedCount = this.rawCases.filter(c => c.Status === 'Closed').length;

        const newPercent = Math.round((newCount / total) * 100);
        const workingPercent = Math.round((workingCount / total) * 100);
        const closedPercent = Math.round((closedCount / total) * 100);

        return {
            newCount,
            newPercent,
            newStyle: `width: ${newPercent}%`,
            workingCount,
            workingPercent,
            workingStyle: `width: ${workingPercent}%`,
            closedCount,
            closedPercent,
            closedStyle: `width: ${closedPercent}%`
        };
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handlePriorityFilterChange(event) {
        this.priorityFilter = event.target.value;
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.target.value;
    }

    handleRefresh() {
        this.isLoading = true;
        this.openMenuRowId = null;
        refreshApex(this.wiredCasesResult)
            .finally(() => {
                this.isLoading = false;
                if (this.activeCaseId) {
                    this.loadActiveCaseDetails(this.activeCaseId);
                }
            });
    }

    toggleRowMenu(event) {
        event.stopPropagation();
        const rowId = event.currentTarget.dataset.id;
        this.openMenuRowId = (this.openMenuRowId === rowId) ? null : rowId;
        this.updateCasesMenuState();
    }

    updateCasesMenuState() {
        this.cases = this.cases.map(c => {
            return {
                ...c,
                isMenuOpen: this.openMenuRowId === c.Id
            };
        });
    }

    closeAllRowMenus() {
        if (this.openMenuRowId !== null) {
            this.openMenuRowId = null;
            this.updateCasesMenuState();
        }
    }

    handleActionClick(event) {
        event.stopPropagation();
        const actionName = event.currentTarget.dataset.action;
        const rowId = event.currentTarget.dataset.id;
        const externalId = event.currentTarget.dataset.externalid;
        this.closeAllRowMenus();

        switch (actionName) {
            case 'view_details':
                this.openDetailModal(rowId, externalId);
                break;
            case 'select_case':
                this.setActiveCase(rowId, externalId);
                break;
            case 'close_case':
                this.openCloseModal(rowId);
                break;
            case 'working_case':
                this.changeCaseStatus(rowId, 'Working', null, null);
                break;
            default:
                break;
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'view_details':
                this.openDetailModal(row.Id, row.External_Case_Id__c);
                break;
            case 'close_case':
                this.openCloseModal(row.Id);
                break;
            case 'working_case':
                this.changeCaseStatus(row.Id, 'Working', null, null);
                break;
            default:
                break;
        }
    }

    openCloseModal(caseId) {
        this.pendingCloseCaseId = caseId;
        this.resolutionSummaryInput = '';
        this.resolutionNotesInput = '';
        this.isCloseModalOpen = true;
    }

    closeCloseModal() {
        this.isCloseModalOpen = false;
        this.pendingCloseCaseId = null;
        this.resolutionSummaryInput = '';
        this.resolutionNotesInput = '';
    }

    handleResolutionSummaryChange(event) {
        this.resolutionSummaryInput = event.target.value;
    }

    handleResolutionNotesChange(event) {
        this.resolutionNotesInput = event.target.value;
    }

    confirmCloseCase() {
        if (!this.resolutionSummaryInput || !this.resolutionSummaryInput.trim()) {
            this.showToast('Error', 'Please enter a resolution summary before closing the Case.', 'error');
            return;
        }
        if (!this.resolutionNotesInput || !this.resolutionNotesInput.trim()) {
            this.showToast('Error', 'Please enter resolution notes before closing the Case.', 'error');
            return;
        }
        const caseId = this.pendingCloseCaseId;
        const summary = this.resolutionSummaryInput.trim();
        const notes = this.resolutionNotesInput.trim();
        this.closeCloseModal();
        this.changeCaseStatus(caseId, 'Closed', notes, summary);
    }

    handleResolveActiveCase() {
        if (this.activeCaseId) {
            this.openCloseModal(this.activeCaseId);
        }
    }

    handleOpenActiveCaseModal() {
        if (this.activeCaseId) {
            this.openDetailModal(this.activeCaseId, this.activeCase ? this.activeCase.External_Case_Id__c : null);
        }
    }

    openDetailModal(caseId, externalCaseId) {
        this.isLoading = true;
        getCaseDetails({ caseId: caseId })
            .then(data => {
                this.selectedCase = data;
                const extId = externalCaseId || (data ? data.External_Case_Id__c : null);
                return Promise.all([
                    extId ? getIntegrationLogs({ externalCaseId: extId }) : Promise.resolve([]),
                    getCaseActivities({ caseId: caseId })
                ]);
            })
            .then(([logs, activities]) => {
                this.integrationLogs = logs || [];
                this.formattedLogs = this.formatLogs(this.integrationLogs);
                this.modalActivities = activities || [];
                this.formattedModalActivities = this.formatActivities(this.modalActivities);
                this.isModalOpen = true;
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : 'Failed to fetch details', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedCase = null;
        this.integrationLogs = [];
        this.formattedLogs = [];
        this.modalActivities = [];
        this.formattedModalActivities = [];
    }

    changeCaseStatus(caseId, newStatus, resolutionNotes = null, resolutionSummary = null) {
        this.isLoading = true;
        updateCaseStatus({ caseId: caseId, newStatus: newStatus, resolutionNotes: resolutionNotes, resolutionSummary: resolutionSummary })
            .then(() => {
                const toastMsg = newStatus === 'Closed' 
                    ? 'Case closed successfully with resolution details.' 
                    : `Case status updated to ${newStatus}`;
                this.showToast('Success', toastMsg, 'success');
                if (this.activeCaseId === caseId) {
                    this.loadActiveCaseDetails(caseId);
                }
                return refreshApex(this.wiredCasesResult);
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : 'Status update failed', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
