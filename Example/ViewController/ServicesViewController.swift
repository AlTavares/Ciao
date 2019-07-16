//
//  ServicesViewController.swift
//  bonjour
//
//  Created by Alexandre Mantovani Tavares on 13/07/19.
//  Copyright © 2019 Alexandre Mantovani Tavares. All rights reserved.
//

import Ciao
import UIKit

class ServicesViewController: UIViewController {
    static let enumeratorService = "_services._dns-sd._udp."
    let tableView = LoadingTableView()

    var datasource = [NetService]()
    override func loadView() {
        view = tableView
    }

    let serviceType: String
    let domain: String
    init(domain: String, serviceType: String = ServicesViewController.enumeratorService) {
        self.domain = domain
        self.serviceType = serviceType
        super.init(nibName: nil, bundle: nil)
        title = domain
    }

    let browser = CiaoBrowser()
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.activityIndicator.startAnimating()

        tableView.register(TableViewCell.self, forCellReuseIdentifier: TableViewCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self

        let handler: (NetService) -> Void = { [weak self] _ in
            guard let self = self else { return }
            self.tableView.activityIndicator.stopAnimating()
            self.datasource = Array(self.browser.services)
            self.tableView.reloadData()
        }

        browser.serviceFoundHandler = handler
        browser.serviceRemovedHandler = handler

        print(serviceType, domain)
        browser.browse(type: serviceType, domain: domain)
    }

    deinit {
        browser.stop()
    }

    required init?(coder: NSCoder) { nil }
}

extension ServicesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        datasource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier, for: indexPath)
        let service = datasource[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = service.name
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let service = datasource[indexPath.row]
        let viewController: UIViewController = {
            switch serviceType == ServicesViewController.enumeratorService {
            case true:
                let fullType = "\(service.name).\(service.type)"
                    .replacingOccurrences(of: "local.", with: "")
                print(fullType)
                let viewController = ServicesViewController(domain: domain, serviceType: fullType)
                viewController.title = service.name
                return viewController
            case false:
                return ServiceDetailViewController(service: service)
            }
        }()

        navigationController?.pushViewController(viewController, animated: true)
    }
}
