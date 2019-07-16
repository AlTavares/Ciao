//
//  ServicesViewController.swift
//  bonjour
//
//  Created by Alexandre Mantovani Tavares on 13/07/19.
//  Copyright © 2019 Alexandre Mantovani Tavares. All rights reserved.
//

import Ciao
import UIKit

class ServiceDetailViewController: UIViewController {
    struct Section {
        var title: String
        var rows: [Row]
    }

    struct Row {
        var text: String
    }

    let tableView = LoadingTableView()
    var datasource: [Section] = []

    override func loadView() {
        view = tableView
    }

    var service: NetService
    let resolver: CiaoResolver
    init(service: NetService) {
        self.service = service
        resolver = CiaoResolver(service: service)
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        resolver.resolve(withTimeout: 0) { [weak self] result in
            guard let self = self else { return }
            self.tableView.activityIndicator.startAnimating()
            print(result)
            switch result {
            case .success(let service):
                self.datasource = [
                    Section(title: service.name, rows: [
                        Row(text: "\(service.hostName ?? ""):\(service.port)")
                    ])
                ]

                if let txtRecords = service.txtRecordDictionary {
                    self.datasource.append(
                        Section(title: "TXT Records",
                                rows: txtRecords.map { "\($0)= \($1)" }.map(Row.init))
                    )
                }
                self.tableView.activityIndicator.stopAnimating()
                self.tableView.reloadData()
            case .failure(let error):
                print(error)
            }
        }

        title = service.type
        tableView.register(TableViewCell.self, forCellReuseIdentifier: TableViewCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
    }

    required init?(coder: NSCoder) { nil }
}

extension ServiceDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return datasource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        datasource[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return datasource[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier, for: indexPath)
        cell.textLabel?.numberOfLines = 0
        let row = datasource[indexPath.section].rows[indexPath.row]
        cell.textLabel?.text = row.text
        return cell
    }
}
