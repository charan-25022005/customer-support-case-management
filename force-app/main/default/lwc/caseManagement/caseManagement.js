import { LightningElement, track, wire } from 'lwc';
import getCases from '@salesforce/apex/CaseService.getCases';
import getCaseDetails from '@salesforce/apex/CaseService.getCaseDetails';
import updateCaseStatus from '@salesforce/apex/CaseService.updateCaseStatus';
import getIntegrationLogs from '@salesforce/apex/CaseService.getIntegrationLogs';
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

const LOG_COLUMNS = [
    { label: 'Log Name', fieldName: 'Name', type: 'text' },
    { label: 'Service', fieldName: 'Service_Name__c', type: 'text' },
    { label: 'Status Code', fieldName: 'Status_Code__c', type: 'number' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Execution Time (ms)', fieldName: 'Execution_Time_ms__c', type: 'number' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' }
];

export default class CaseManagement extends LightningElement {
    @track searchTerm = '';
    @track priorityFilter = 'ALL';
    @track statusFilter = 'ALL';
    @track cases = [];
    @track rawCases = [];
    @track isLoading = true;

    @track selectedCase = null;
    @track integrationLogs = [];
    @track isModalOpen = false;
    @track isCloseModalOpen = false;
    @track pendingCloseCaseId = null;
    @track resolutionNotesInput = '';

    @track openMenuRowId = null;

    wiredCasesResult;

    columns = COLUMNS;
    logColumns = LOG_COLUMNS;

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

                return {
                    ...c,
                    OwnerName: ownerName,
                    ownerInitials: ownerInitials,
                    isVip: isVip,
                    statusBadgeClass: this.getStatusBadgeClass(status),
                    priorityBadgeClass: this.getPriorityBadgeClass(priority),
                    isMenuOpen: this.openMenuRowId === c.Id
                };
            });
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
        if (!status) return 'badge-pill badge-status-new';
        const s = status.toLowerCase();
        if (s === 'closed') return 'badge-pill badge-status-closed';
        if (s === 'working' || s === 'in progress') return 'badge-pill badge-status-working';
        return 'badge-pill badge-status-new';
    }

    getPriorityBadgeClass(priority) {
        if (!priority) return 'badge-pill badge-priority-low';
        const p = priority.toLowerCase();
        if (p === 'high') return 'badge-pill badge-priority-high';
        if (p === 'medium') return 'badge-pill badge-priority-medium';
        return 'badge-pill badge-priority-low';
    }

    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    get hasLogs() {
        return this.integrationLogs && this.integrationLogs.length > 0;
    }

    get selectedCaseOwnerName() {
        return this.selectedCase && this.selectedCase.Owner ? this.selectedCase.Owner.Name : '';
    }

    get selectedCaseResolutionNotes() {
        return this.selectedCase && this.selectedCase.Resolution_Notes__c ? this.selectedCase.Resolution_Notes__c : 'No resolution recorded yet.';
    }

    get selectedCaseStatusBadgeClass() {
        return this.selectedCase ? this.getStatusBadgeClass(this.selectedCase.Status) : 'badge-pill badge-status-new';
    }

    get selectedCasePriorityBadgeClass() {
        return this.selectedCase ? this.getPriorityBadgeClass(this.selectedCase.Priority) : 'badge-pill badge-priority-low';
    }

    get metrics() {
        let total = this.rawCases.length;
        let open = this.rawCases.filter(c => c.Status !== 'Closed').length;
        let highPriority = this.rawCases.filter(c => c.Priority === 'High').length;
        let vip = this.rawCases.filter(c => c.Is_VIP__c === true).length;
        return { total, open, highPriority, vip };
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
            case 'close_case':
                this.openCloseModal(rowId);
                break;
            case 'working_case':
                this.changeCaseStatus(rowId, 'Working', null);
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
                this.changeCaseStatus(row.Id, 'Working', null);
                break;
            default:
                break;
        }
    }

    openCloseModal(caseId) {
        this.pendingCloseCaseId = caseId;
        this.resolutionNotesInput = '';
        this.isCloseModalOpen = true;
    }

    closeCloseModal() {
        this.isCloseModalOpen = false;
        this.pendingCloseCaseId = null;
        this.resolutionNotesInput = '';
    }

    handleResolutionNotesChange(event) {
        this.resolutionNotesInput = event.target.value;
    }

    confirmCloseCase() {
        if (!this.resolutionNotesInput || !this.resolutionNotesInput.trim()) {
            this.showToast('Error', 'Please enter resolution notes before closing the Case.', 'error');
            return;
        }
        const caseId = this.pendingCloseCaseId;
        const notes = this.resolutionNotesInput.trim();
        this.closeCloseModal();
        this.changeCaseStatus(caseId, 'Closed', notes);
    }

    openDetailModal(caseId, externalCaseId) {
        this.isLoading = true;
        getCaseDetails({ caseId: caseId })
            .then(data => {
                this.selectedCase = data;
                return getIntegrationLogs({ externalCaseId: externalCaseId });
            })
            .then(logs => {
                this.integrationLogs = logs;
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
    }

    changeCaseStatus(caseId, newStatus, resolutionNotes = null) {
        this.isLoading = true;
        updateCaseStatus({ caseId: caseId, newStatus: newStatus, resolutionNotes: resolutionNotes })
            .then(() => {
                this.showToast('Success', `Case status updated to ${newStatus}`, 'success');
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
