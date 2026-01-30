//
//  DocumentSelectionInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import Foundation

final class DocumentSelectionInteractor {
    weak var presenter: DocumentSelectionInteractorToPresenter?

    init(presenter: DocumentSelectionInteractorToPresenter?) {
        self.presenter = presenter
    }
}

extension DocumentSelectionInteractor: DocumentSelectionPresenterToInteractor {
    func fetchSupportedCountries() {
        // Supported countries.
        let countries: [NativeCountry] = [
            .all, .ar, .br, .cl, .co, .cr, .mx, .pe, .sv, .ve
        ]
        Task { await presenter?.didLoadCountries(countries) }
    }
}
