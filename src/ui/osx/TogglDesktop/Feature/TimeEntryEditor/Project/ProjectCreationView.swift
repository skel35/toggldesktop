//
//  ProjectCreationView.swift
//  TogglDesktop
//
//  Created by Nghia Tran on 3/28/19.
//  Copyright © 2019 Alari. All rights reserved.
//

import Cocoa

protocol ProjectCreationViewDelegate: class {

    func projectCreationDidCancel()
    func projectCreationDidAdd()
    func projectCreationDidUpdateSize()
}

final class ProjectCreationView: NSView {

    enum DisplayMode {
        case compact
        case full // with color picker

        var height: CGFloat {
            switch self {
            case .compact:
                return 200.0
            case .full:
                return 400.0
            }
        }
    }

    // MARK: OUTLET

    @IBOutlet weak var addBtn: NSButton!
    @IBOutlet weak var projectTextField: NSTextField!
    @IBOutlet weak var workspaceAutoComplete: WorkspaceAutoCompleteTextField!
    @IBOutlet weak var clientAutoComplete: ClientAutoCompleteTextField!
    @IBOutlet weak var colorBtn: CursorButton!
    @IBOutlet weak var colorPickerContainerView: NSView!
    @IBOutlet weak var publicProjectCheckBox: NSButton!
    
    // MARK: Variables

    var selectedTimeEntry: TimeEntryViewItem!
    private(set) var selectedWorkspace: Workspace?
    private(set) var selectedClient: Client?
    private var isPublic = false
    private lazy var clientDatasource = ClientDataSource.init(items: ClientStorage.shared.clients,
                                                              updateNotificationName: .ClientStorageChangedNotification)
    private lazy var workspaceDatasource = WorkspaceDataSource.init(items: WorkspaceStorage.shared.workspaces,
                                                                    updateNotificationName: .WorkspaceStorageChangedNotification)
    weak var delegate: ProjectCreationViewDelegate?
    private var originalColor = ProjectColor.default
    private var selectedColor = ProjectColor.default {
        didSet {
            updateSelectColorView()
        }
    }
    private lazy var colorPickerView: ColorPickerView = {
        let picker = ColorPickerView.xibView() as ColorPickerView
        picker.delegate = self
        colorPickerContainerView.addSubview(picker)
        picker.edgesToSuperView()
        return picker
    }()
    private var displayMode = DisplayMode.compact {
        didSet {
            updateLayout()
        }
    }
    var suitableHeight: CGFloat {
        return displayMode.height
    }
    var isValidDataForProjectCreation: Bool {
        return selectedClient != nil && selectedWorkspace != nil && !projectTextField.stringValue.isEmpty
    }

    // MARK: Public

    override func awakeFromNib() {
        super.awakeFromNib()

        initCommon()
        updateLayoutState()
        selecteFirstWorkspace()
    }

    func setTitleAndFocus(_ title: String) {
        projectTextField.stringValue = title
        window?.makeFirstResponder(projectTextField)
    }

    @IBAction func cancelBtnOnTap(_ sender: Any) {
        delegate?.projectCreationDidCancel()
    }

    @IBAction func addBtnOnTap(_ sender: Any) {
        guard isValidDataForProjectCreation else { return }
        guard let selectedWorkspace = selectedWorkspace, let selectedClient = selectedClient else {
            return
        }

        // Safe for unwrapped
        let isBillable = selectedTimeEntry.billable
        let timeEntryGUID = selectedTimeEntry.guid!
        let workspaceID = selectedWorkspace.ID
        let clientID = selectedClient.ID
        let clientGUID = selectedClient.guid!
        let projectName = projectTextField.stringValue
        let colorHex = selectedColor.colorHex

        let projectID = DesktopLibraryBridge.shared().createProject(withTimeEntryGUID: timeEntryGUID,
                                                                    workspaceID: workspaceID,
                                                                    clientID: clientID,
                                                                    clientGUID: clientGUID,
                                                                    projectName: projectName,
                                                                    colorHex: colorHex,
                                                                    isPublic: isPublic)
        if selectedTimeEntry.billable {
            DesktopLibraryBridge.shared().setBillableForTimeEntryWithTimeEntryGUID(timeEntryGUID,
                                                                                   isBillable: isBillable)
        }
        delegate?.projectCreationDidAdd()
    }

    @IBAction func publicProjectOnChange(_ sender: Any) {
        isPublic = publicProjectCheckBox.state == .on
    }

    @IBAction func colorBtnOnTap(_ sender: Any) {
        let isON = colorBtn.state == .on
        displayMode = isON ? .full : .compact
        colorBtn.layer?.borderWidth = isON ? 4.0 : 0.0
    }
}

// MARK: Private

extension ProjectCreationView {

    fileprivate func initCommon() {
        colorPickerView.isHidden = false
        colorPickerContainerView.isHidden = true
        colorBtn.wantsLayer = true
        colorBtn.layer?.cornerRadius = 12.0
        colorBtn.layer?.borderColor = colorBtnBorderColor.cgColor
        colorBtn.cursor = .pointingHand

        // Default value
        selectedColor = ProjectColor.default
        displayMode = .compact

        // Delegate
        clientAutoComplete.autoCompleteDelegate = self

        // Setup data source
        clientDatasource.delegate = self
        clientDatasource.setup(with: clientAutoComplete)
        workspaceDatasource.delegate = self
        workspaceDatasource.setup(with: workspaceAutoComplete)
    }

    fileprivate func updateLayout() {
        let height = displayMode.height
        switch displayMode {
        case .compact:
            colorPickerContainerView.isHidden = true
            self.frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: height)
        case .full:
            colorPickerContainerView.isHidden = false
            self.frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: height)
        }
        delegate?.projectCreationDidUpdateSize()
    }

    fileprivate func updateSelectColorView() {
        colorBtn.layer?.backgroundColor = ConvertHexColor.hexCode(toNSColor: selectedColor.colorHex)!.cgColor
        colorPickerView.select(selectedColor)
    }

    fileprivate var colorBtnBorderColor: NSColor {
        if #available(OSX 10.13, *) {
            return NSColor(named: "color-project-btn-border-color")!
        } else {
            return NSColor(white: 0, alpha: 0.1)
        }
    }

    fileprivate func createNewClient(with name: String) {
        guard !name.isEmpty else { return }

        // Focus to workspace text field if user hasn't selected any workspace
        guard let workspace = selectedWorkspace else {
            window?.makeFirstResponder(workspaceAutoComplete)
            return
        }

        let newClientGUID = DesktopLibraryBridge.shared().createClient(withWorkspaceID: workspace.ID, clientName: name)
        if let newClient = ClientStorage.shared.clients.first(where: { $0.guid == newClientGUID }) {
            self.selectedClient = newClient
        }
    }

    fileprivate func updateLayoutState() {
        guard isValidDataForProjectCreation else {
            addBtn.isEnabled = false
            return
        }

        addBtn.isEnabled = true
    }

    fileprivate func selecteFirstWorkspace() {
        guard !workspaceDatasource.items.isEmpty else { return }
        workspaceDatasource.selectRow(at: 0)
    }
}

// MARK: ColorPickerViewDelegate

extension ProjectCreationView: ColorPickerViewDelegate {

    func colorPickerDidSelectColor(_ color: ProjectColor) {
        selectedColor = color
    }

    func colorPickerShouldResetColor() {
        selectedColor = originalColor
    }
}

// MARK: AutoCompleteViewDataSourceDelegate

extension ProjectCreationView: AutoCompleteViewDataSourceDelegate {

    func autoCompleteSelectionDidChange(sender: AutoCompleteViewDataSource, item: Any) {
        if sender == clientDatasource {
            guard let client = item as? Client else { return }
            self.selectedClient = client
            clientAutoComplete.stringValue = client.name
            clientAutoComplete.closeSuggestion()
        }
        if sender == workspaceDatasource {
            guard let workspace = item as? Workspace else { return }
            self.selectedWorkspace = workspace
            workspaceAutoComplete.stringValue = workspace.name
            workspaceAutoComplete.closeSuggestion()
        }

        // Update add button
        updateLayoutState()
    }
}

// MARK: AutoCompleteTextFieldDelegate

extension ProjectCreationView: AutoCompleteTextFieldDelegate {

    func autoCompleteDidTapOnCreateButton(_ sender: AutoCompleteTextField) {
        if sender == clientAutoComplete {
            clientAutoComplete.closeSuggestion()
            createNewClient(with: clientAutoComplete.stringValue)
            updateLayoutState()
        }
    }
}