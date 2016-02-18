//
//  thing_with_codes.swift
//  CDAKit
//
//  Created by Eric Whitley on 11/30/15.
//  Copyright © 2015 Eric Whitley. All rights reserved.
//

import Foundation

public protocol CDAKThingWithCodes: class, CDAKJSONExportable {
  var codes: CDAKCodedEntries { get set }
}

extension CDAKThingWithCodes {
  
  func single_code_value() -> Bool {
    guard let (_, first_val) = codes.first else {
      return false
    }
    return codes.count == 1 && first_val.codes.count == 1
  }
  
  func codes_to_s() -> String {
    return convert_codes_to_s(codes)
  }
  
  func convert_codes_to_s(codes: CDAKCodedEntries) -> String {
    return codes.map { (code_set, codes) in ("\(code_set): " + codes.codes.joinWithSeparator(", ")) }.joinWithSeparator(" ")
  }
  
  /**
   Will return a single code and code set if one exists in the code sets that are passed in. Returns a hash with a key of code and code_set if found, nil otherwise
  */
  func preferred_code(var preferred_code_sets: [String], codes_attribute: String? = "codes", value_set_map: [CDAKCodedEntries] = []) -> CDAKCodedEntry?//[String:String]?
  {

    //FIXME: - likely issues here with send() and the way I'm pulling this in
    // count here doesn't really make sense relative to nil, but...
    // I can't think of another way to do this...
    // I can't reference "codes" in the function header
    // but... by doing what we're doing here, we're ignoring the situation where
    // someone intentionally sends in an empty collection
    // I really don't like dealing with nilable collections
    // potential fix - set this to a nilable collection
    var codes_value: CDAKCodedEntries = CDAKCodedEntries()
    switch codes_attribute {
      case let codes_attribute where codes_attribute == "codes": codes_value = self.codes
    default:
      print("ThingWithCodes.preferred_code() didn't find codes_attribute '\(codes_attribute)', defaulting to 'codes''")
    }
    
    if value_set_map.count > 0 {
      preferred_code_sets = Array(Set(preferred_code_sets).intersect(value_set_map.map({cs in cs.keys}).flatMap({$0})))
    }
    
    let matching_code_sets = Array(Set(preferred_code_sets).intersect(codes_value.keys))

    //FIXME: - this is all definitely wrong, but I'm flying blind
    if matching_code_sets.count > 0 {
      if value_set_map.count > 0 {
        for matching_code_set in matching_code_sets {
          var matching_codes: [String] = [String]()
          var codes_value_matching_code_set: [String] = [String]()
          if let somecodes = codes_value[matching_code_set] {
            codes_value_matching_code_set = somecodes.codes
          }

          matching_codes = Array(Set(value_set_map.map({ cs in cs.findIntersectingCodes(forCodeSystem: matching_code_set, matchingCodes:codes_value_matching_code_set) }).flatMap({$0}).flatMap({$0})))

          return codes.findIntersectingCodedEntries(forCodeSystem: matching_code_set, matchingCodes: matching_codes)
          
//          matching_codes = Array(Set(value_set_map.map({ cs in cs.findIntersectingCodes(forCodeSystem: matching_code_set, matchingCodes:codes_value_matching_code_set) }).flatMap({$0}).flatMap({$0})))
//
//          if matching_codes.count > 0 {
//            if let code_set = matching_code_sets.first {
//              return CDAKCodedEntry(codeSystem: code_set, codes: codes_value[code_set]!.first!)
//            }
//          }
        }
        //# we did not find a matching preferred code... we cannot write this out to QRDA
        return nil
      } else {
        if let code_set = matching_code_sets.first {
//          return CDAKCodedEntry(codeSystem: code_set, codes: codes_value[code_set]!.first!)
          if let matching_codes = codes_value[code_set] {
            return codes.findIntersectingCodedEntries(forCodeSystem: code_set, matchingCodes: matching_codes.codes)
          }
        }
      }
      
    } else {
      return nil
    }
    return nil
  }

  
  
  /**
     Will return an Array of code and code_set hashes for all codes for this entry except for the preferred_code. It is intended that these codes would be used in the translation elements as childern of a CDA code element
     
     EWW: apparently if you have multiple in the same code set, only the first (which seems to be the preferred) is removed - all the rest are returned
     
     NOTE "value_set_map" is defined in...
     health-data-standards/lib/health-data-standards/export/helper/scooped_view_helper.rb
     
     Value set Map appears to look like...
     [{"set"=>"RxNorm", "values"=>["89905"]}]
     ->[CDAKCodedEntries]
     
     Code Set appears to look like...
     [{"set"=>"RxNorm", "values"=>["89905"]}]
     ->[CDAKCodedEntries], but also... [[String:String]]
     
     preferred_code_sets looks like...
     ["SOP", "Source of Payment Typology"]
  */
  func translation_codes(preferred_code_sets: [String], value_set_map: [CDAKCodedEntries] = []) -> CDAKCodedEntries {
    
    var tx_codes: CDAKCodedEntries = CDAKCodedEntries()
//    var matching_codes: CDAKCodedEntries = CDAKCodedEntries()
    
    tx_codes = value_set_map.count > 0 ? codes_in_code_set(value_set_map) : codes
//    matching_codes = value_set_map.count > 0 ? codes_in_code_set(value_set_map) : codes
//    for (code_set, code_list) in matching_codes {
//      for code in code_list {
//        tx_codes.addCodes(code_set, codes: [code])
//      }
//    }
    
    var pref_code = CDAKCodedEntries()
    if let somecodes = preferred_code(preferred_code_sets, codes_attribute: "codes", value_set_map: value_set_map) {
        //pref_code.addCodes([somecodes])
      pref_code[somecodes.codeSystem] = somecodes
    }
    //translation codes are those NOT in the originating values
    // EX: we pass in SNOMED:123 and check against SNOMED:123 and LOINC:456
    // we want to return LOINC:456
    tx_codes.removeCodes(foundInEntries: pref_code)
    
    return tx_codes
  }

  
  /**
     Checks if a code is in the list of possible codes
     
     - parameter code_set: an Array of Hashes that describe the values for code sets.  The hash has a key of "set" for the code system name and "values" for the actual code list
     
     - returns: all codes that are in the code set

  */
  func codes_in_code_set(code_set: [CDAKCodedEntries]) -> CDAKCodedEntries {
    var matching: CDAKCodedEntries = CDAKCodedEntries()
    
    for code_system in codes.keys {
      //var matching_codes: [String] = []
      let all_codes_in_system = code_set.filter({set in set["set"]?.first == code_system})

      for entries in all_codes_in_system {
        if let entry = entries[code_system] {
          if let matchingEntry = codes.findIntersectingCodedEntries(forCodeSystem: code_system, matchingCodes: entry.codes) {
            matching[code_system] = matchingEntry
          }
        }
      }
//      for codes_in_system in all_codes_in_system {
//        if let values = codes_in_system["values"] {
//          matching_codes.appendContentsOf(values)
//        }
//        if let values = codes[code_system] {
//          matching_codes.appendContentsOf(values)
//        }
//      }
//      matching_codes = Array(Set(matching_codes)) //bad de-dupe
//      matching[code_system] = CDAKCodedEntry(codeSystem: code_system, codes: matching_codes)
//      //NOTE : moving this code down to the bottom - in the original Ruby it's at the top
//      // Ruby will retain the reference between the dictionary entry and the array, so
//      // we're moving this to the bottom since Swift doesn't really do that
    }
    
    return matching
  }

  /**
    Add a code into the CDAKEntry
    
    - parameter code: the code to add
  
    - parameter code_system: the code system that the code belongs to
  */
  func add_code(code:Any, code_system:String, code_system_oid: String? = nil, display_name: String? = nil) {
    let code_str = String(code)
    if let cd = codes[code_system] {
      if !cd.contains(code_str) {
        codes.addCodes(code_system, codes: code_str, codeSystemOid: code_system_oid, displayName: display_name)
      }
    } else {
      codes[code_system] = CDAKCodedEntry(codeSystem: code_system, codes: [code_str], codeSystemOid: code_system_oid, displayName: display_name)
    }
  }


  
}

extension CDAKThingWithCodes {
  public var jsonDict: [String: AnyObject] {
    var dict: [String: AnyObject] = [:]
    
    if codes.count > 0 {
      dict["codes"] = codes.codes.map({$0.jsonDict})
    }
    
    return dict
  }
}
