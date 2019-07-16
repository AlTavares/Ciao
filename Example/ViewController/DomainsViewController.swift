//
//  ServicesViewController.swift
//  bonjour
//
//  Created by Alexandre Mantovani Tavares on 13/07/19.
//  Copyright © 2019 Alexandre Mantovani Tavares. All rights reserved.
//

import Ciao
import UIKit

class DomainsViewController: UIViewController {
    let tableView = UITableView()

    var datasource: [String]
    override func loadView() {
        view = tableView
    }

    init(domains: String...) {
        self.datasource = domains
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "domains"
        tableView.register(TableViewCell.self, forCellReuseIdentifier: TableViewCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
    }

    required init?(coder: NSCoder) { nil }
}

extension DomainsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        datasource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier, for: indexPath)
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = datasource[indexPath.row]
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let domain = datasource[indexPath.row]
        let servicesViewController = ServicesViewController(domain: domain)
        navigationController?.pushViewController(servicesViewController, animated: true)
    }
}
