*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium    auto_close=${True}
Library             RPA.PDF
Library             RPA.HTTP
Library             RPA.Tables
Library             OperatingSystem
Library             DateTime
Library             Dialogs
Library             Screenshot
Library             RPA.Archive
Library             RPA.Robocorp.Vault

*** Variables ***
${receipt_dir}=    ${OUTPUT_DIR}${/}receipt/
${img_dir}=    ${OUTPUT_DIR}${/}img/
${zip_dir}=    ${OUTPUT_DIR}${/}archives/

*** Tasks ***
InsertOrders
    get_order_list
    open_order_site
    make_orders_form_csv
    create_zip_archive
    cleanup_temporary_files
    [Teardown]    Close Browser

*** Keywords ***
get_order_list
    # ${secret}=    Get Secret    urls
    # dowload_csv_file      ${secret}[order_page_url] 
    dowload_csv_file    https://robotsparebinindustries.com/orders.csv

dowload_csv_file
    [Arguments]     ${address}
    Download        ${address}    overwrite=True

open_order_site
    Open Available Browser    https://robotsparebinindustries.com/#/robot-order

click_ok_on_popup
    Wait Until Page Contains Element    class:alert-buttons
    Click Button    OK

order_button_confirm
    Click Button    Order
    Page Should Contain Element    id:receipt

return_to_order_form
    Wait Until Element Is Visible    id:order-another
    Click Button    id:order-another

make_single_order
    [Arguments]    ${orders}
    click_ok_on_popup
    Wait Until Page Contains Element    class:form-group
    Select From List By Index    head    ${orders}[Head]
    Select Radio Button    body    ${orders}[Body]
    Input Text    xpath://html/body/div/div/div[1]/div/div[1]/form/div[3]/input    ${orders}[Legs]
    Input Text    address    ${orders}[Address]
    Click Button    Preview
    Wait Until Keyword Succeeds    2min    500ms    order_button_confirm

make_pdf_for_single_receipt
    [Arguments]    ${receipt_filename}    ${image_filename}
    Open PDF    ${receipt_filename}
    @{file_list}=    Create List
    ...    ${receipt_filename}
    ...    ${image_filename}
    
    Add Files To Pdf    ${file_list}    ${receipt_filename}    append=${False}
    Close Pdf

make_order_receipt
    Wait Until Element Is Visible    id:receipt
    ${order_id}=    Get Text    //*[@id="receipt"]/p[1]
    Set Local Variable    ${receipt_filename}    ${receipt_dir}receipt_${order_id}.pdf
    ${receipt_html}=    Get Element Attribute    //*[@id="receipt"]    outerHTML
    Html To Pdf    content=${receipt_html}    output_path=${receipt_filename}

    Wait Until Element Is Visible    id:robot-preview-image
    Set Local Variable    ${image_filename}    ${img_dir}robot_${order_id}.png
    Screenshot    id:robot-preview-image    ${image_filename}
    make_pdf_for_single_receipt    ${receipt_filename}    ${image_filename}

create_zip_archive
    Create Directory    ${zip_dir}
    ${date}=    Get Current Date
    ${timestamp}=    Convert Date    ${date}    result_format=%d%m%Y%H%M%S
    ${zip_file_name}=    Set Variable    ${zip_dir}${/}${timestamp}.zip
    Archive Folder With Zip    ${receipt_dir}    ${zip_file_name}

cleanup_temporary_files
    Remove Directory    ${receipt_dir}    True
    Remove Directory    ${img_dir}    True

make_orders_form_csv
    ${orders}=    Read table from CSV    path=orders.csv
    FOR    ${order}    IN    @{orders}
        make_single_order    ${order}
        make_order_receipt
        return_to_order_form
    END
    

