# Health Information Sources

gTimer localises the Health & Safety support rows by country. Use the last reverse-geocoded country code when the user has already granted location access; otherwise fall back to the device region. Do not request precise location solely to choose health content.

Emergency-service phone numbers are also localised by country. The broad reference table is maintained in `docs/emergency-numbers-by-country.md`; the app should use the saved home country first, then the last known location country, then the device region.

Core safety content should stay conservative across regions:

- GHB/GBL are central nervous system depressants.
- Avoid mixing with alcohol, benzodiazepines, opioids, or other depressants.
- Treat unconsciousness, slow or irregular breathing, seizure, blue lips/fingertips, vomiting while not fully conscious, or uncertainty as an emergency.
- Dependence and withdrawal can be serious and should be medically supervised.

## Country Sources

| Country | Emergency | Drug/alcohol support | Poison/medical advice | GHB/source material |
| --- | --- | --- | --- | --- |
| Australia | Triple Zero: https://www.infrastructure.gov.au/media-communications/phone/triple-zero | National Alcohol and Other Drug Hotline: https://www.health.gov.au/contacts/national-alcohol-and-other-drug-hotline | Poisons Information Centre: https://www.poisonsinfo.nsw.gov.au/ | Healthdirect: https://www.healthdirect.gov.au/ghb and ADF: https://adf.org.au/insights/hidden-harms-ghb/ |
| New Zealand | New Zealand Police 111: https://www.police.govt.nz/call-111 | Alcohol Drug Helpline: https://alcoholdrughelp.org.nz/ | National Poisons Centre: https://poisons.co.nz/ | NZ Drug Foundation: https://drugfoundation.org.nz/drugs-a-z/ghbgbl |
| United Kingdom | NHS 999: https://www.nhs.uk/nhs-services/urgent-and-emergency-care-services/when-to-call-999/ | FRANK: https://talktofrank.com/contact-frank | NPIS public guidance: https://www.npis.org/ | FRANK GHB & GBL: https://talktofrank.com/drug/ghb |
| Ireland | HSE 112/999: https://www2.hse.ie/emergencies/when-to-call-112-or-999/ | HSE Drugs & Alcohol Helpline: https://www.drugs.ie/phone | National Poisons Information Centre: https://poisons.ie/ | Drugs.ie GHB risk reduction: https://www.drugs.ie/ghb_information_and_risk_reduction/ |
| United States | National 911 Program: https://www.911.gov/ | SAMHSA National Helpline: https://www.samhsa.gov/find-help/helplines/national-helpline | Poison Help: https://poisonhelp.hrsa.gov/poison-centers/find-poison-center | SAMHSA/NIDA treatment routing and poison guidance |
| Canada | Local emergency services use 911 in most areas; Health Canada support page is the primary national source for support rows: https://www.canada.ca/en/health-canada/services/substance-use/get-help-with-substance-use.html | National Overdose Response Service via Health Canada support page | Health Canada poison centre number: https://www.canada.ca/en/health-canada/news/2023/03/canada-launches-new-toll-free-1-844-poison-x-number-for-poison-centres.html | Health Canada GHB: https://www.canada.ca/en/health-canada/services/substance-use/controlled-illegal-drugs/ghb.html |
| South Africa | Western Cape emergency-number guide: https://www.westerncape.gov.za/know-who-you-can-call-emergency | South African Government substance abuse support: https://www.gov.za/Alcoholandsubstanceabuse | UCT Poisons Information Centre: https://health.uct.ac.za/department-paediatrics/clinical-services-medical-services/poisons-information-centre | Use local support sources plus conservative shared GHB warnings |

## Maintenance

Review these rows before App Store release and at least yearly, because phone numbers and public health service names can change. Prefer national government, national health service, poison centre, or nationally recognised harm-reduction sources over blogs or treatment-centre marketing pages.
