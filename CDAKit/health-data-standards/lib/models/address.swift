//
//  address.swift
//  CDAKit
//
//  Created by Eric Whitley on 11/30/15.
//  Copyright © 2015 Eric Whitley. All rights reserved.
//

import Foundation

/**
Represents a physical address
*/
public class CDAKAddress: NSObject, CDAKJSONInstantiable {
  
  ///Pointer back to parent record
  var record: CDAKRecord?
  
  // MARK: CDA properties
  ///Street
  public var street: [String] = [String]()
  ///City
  public var city: String?
  ///State
  public var state: String?
  ///Zip code
  public var zip: String?
  ///Country code
  public var country: String?
  /**
   HL7 Address Use codes
   HL7 OID: 2.16.840.1.113883.5.1119
   [Reference] (https://www.hl7.org/fhir/v3/AddressUse/index.html)
  */
  public var use: String?
  
  // MARK: - Initializers
  public override init(){
    super.init()
  }
  
  public init(street:[String] = [], city: String?, state: String?, zip: String?, country: String?, use: String?) {
    super.init()
    self.street = street
    self.city = city
    self.state = state
    self.zip = zip
    self.country = country
    self.use = use
  }
  
  required public init(event: [String:Any?]) {
    super.init()
    initFromEventList(event)
  }
  
  private func initFromEventList(event: [String:Any?]) {
    for (key, value) in event {
      CDAKUtility.setProperty(self, property: key, value: value)
    }
  }

  // MARK: Standard properties
  ///Debugging description
  override public var description: String {
    return "CDAKAddress => street: \(street), city: \(city), state: \(state), zip: \(zip), country: \(country), use: \(use)"
  }
  
}

// MARK: - JSON Generation
extension CDAKAddress: CDAKJSONExportable {
  ///Dictionary for JSON data
  public var jsonDict: [String: AnyObject] {
    var dict: [String: AnyObject] = [:]
    if street.count > 0 {
      dict["street"] = street
    }
    if let city = city {
      dict["city"] = city
    }
    if let state = state {
      dict["state"] = state
    }
    if let zip = zip {
      dict["zip"] = zip
    }
    if let country = country {
      dict["country"] = country
    }
    if let use = use {
      dict["use"] = use
    }
    return dict
  }
}