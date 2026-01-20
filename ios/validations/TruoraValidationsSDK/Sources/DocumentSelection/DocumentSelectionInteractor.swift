//
//  DocumentSelectionInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import Foundation
import TruoraShared

final class DocumentSelectionInteractor {
    weak var presenter: DocumentSelectionInteractorToPresenter?

    init(presenter: DocumentSelectionInteractorToPresenter?) {
        self.presenter = presenter
    }
}

extension DocumentSelectionInteractor: DocumentSelectionPresenterToInteractor {
    func fetchSupportedCountries() {
        // Must match KMP supported countries.
        let countries: [TruoraCountry] = [
            .all, .ar, .br, .cl, .co, .cr, .mx, .pe, .sv, .ve
        ]
        presenter?.didLoadCountries(countries)
    }
}
